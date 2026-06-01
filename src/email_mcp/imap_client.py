"""IMAP client for fetching and searching emails."""

import imaplib
import email
from email.header import decode_header
from email.message import Message as EmailMessage
from email.utils import parseaddr, parsedate_to_datetime
from typing import Optional
import html2text
import re

from .crypto import decrypt


def _decode_str(s: Optional[str]) -> str:
    """Decode RFC 2047 encoded header value."""
    if not s:
        return ""
    parts = decode_header(s)
    decoded = []
    for part, charset in parts:
        if isinstance(part, bytes):
            decoded.append(part.decode(charset or "utf-8", errors="replace"))
        else:
            decoded.append(part)
    return "".join(decoded)


def _extract_addr(header_val: Optional[str]) -> str:
    """Extract name and address from a From/To/Cc header."""
    if not header_val:
        return ""
    decoded = _decode_str(header_val)
    name, addr = parseaddr(decoded)
    if name and addr:
        return f"{name} <{addr}>"
    return decoded.strip()


def _html_to_text(html: str) -> str:
    """Convert HTML to clean plain text."""
    h = html2text.HTML2Text()
    h.ignore_links = False
    h.ignore_images = True
    h.ignore_tables = False
    h.body_width = 0  # no wrapping
    text = h.handle(html)
    # Trim common signatures/footers
    lines = text.splitlines()
    clean = []
    in_sig = False
    for line in lines:
        stripped = line.strip()
        if stripped in ("--", "-- ", "___", "---"):
            in_sig = True
        if in_sig:
            continue
        if stripped.startswith("-----Original Message-----"):
            break
        clean.append(line)
    return "\n".join(clean).strip()


def _get_text_body(msg: EmailMessage) -> tuple[str, str]:
    """Extract (plain_text, html) from a message."""
    plain = ""
    html = ""
    if msg.is_multipart():
        for part in msg.walk():
            ct = (part.get_content_type() or "").lower()
            if ct == "text/plain" and not plain:
                payload = part.get_payload(decode=True)
                if payload:
                    charset = part.get_content_charset() or "utf-8"
                    plain = payload.decode(charset, errors="replace")
            elif ct == "text/html" and not html:
                payload = part.get_payload(decode=True)
                if payload:
                    charset = part.get_content_charset() or "utf-8"
                    html = payload.decode(charset, errors="replace")
    else:
        ct = (msg.get_content_type() or "").lower()
        payload = msg.get_payload(decode=True)
        if payload:
            charset = msg.get_content_charset() or "utf-8"
            decoded = payload.decode(charset, errors="replace")
            if ct == "text/html":
                html = decoded
            else:
                plain = decoded
    if html and not plain:
        plain = _html_to_text(html)
    return plain, html


def _get_flags(msg_data: list) -> str:
    """Extract IMAP flags from FETCH response."""
    if not msg_data:
        return ""
    for item in msg_data:
        if isinstance(item, bytes) and item.startswith(b"("):
            return item.decode("utf-8", errors="replace")
    return ""


class IMAPClient:
    def __init__(self, host: str, port: int, ssl: bool, username: str, password: str):
        self.host = host
        self.port = port
        self.ssl = ssl
        self.username = username
        self.password = password
        self.conn: Optional[imaplib.IMAP4_SSL | imaplib.IMAP4] = None

    def connect(self):
        if self.ssl:
            self.conn = imaplib.IMAP4_SSL(self.host, self.port)
        else:
            self.conn = imaplib.IMAP4(self.host, self.port)
        self.conn.login(self.username, self.password)
        return self.conn

    def disconnect(self):
        if self.conn:
            try:
                self.conn.logout()
            except Exception:
                pass
            self.conn = None

    def list_folders(self) -> list[str]:
        if not self.conn:
            self.connect()
        status, data = self.conn.list()
        folders = []
        if status == "OK":
            for item in data:
                if item:
                    raw = item.decode("utf-8", errors="replace") if isinstance(item, bytes) else item
                    # Format: (\HasNoChildren) "." "INBOX.Sent"
                    # The delimiter may vary; extract the last quoted part
                    parts = raw.split('"')
                    # Find pairs of quotes — folder name is in the last quoted segment
                    if len(parts) >= 3:
                        folder = parts[-2]
                        folders.append(folder)
        return folders

    def fetch_messages(self, folder: str, limit: int = 100) -> list[dict]:
        """Fetch latest messages from a folder."""
        if not self.conn:
            self.connect()
        status, _ = self.conn.select(folder, readonly=True)
        if status != "OK":
            return []

        # Search all messages
        status, data = self.conn.search(None, "ALL")
        if status != "OK" or not data[0]:
            return []

        uids = data[0].split()
        # Get the most recent `limit` messages
        uids = uids[-limit:] if len(uids) > limit else uids

        messages = []
        for uid in uids:
            try:
                status, msg_data = self.conn.fetch(uid, "(RFC822 FLAGS)")
                if status != "OK" or not msg_data:
                    continue
                raw_email = msg_data[0][1]
                flags = _get_flags(msg_data[0])
                msg = email.message_from_bytes(raw_email)
                plain, html = _get_text_body(msg)
                date_str = msg.get("Date", "")
                try:
                    dt = parsedate_to_datetime(date_str).isoformat()
                except Exception:
                    dt = date_str
                messages.append({
                    "message_uid": uid.decode("utf-8", errors="replace") if isinstance(uid, bytes) else str(uid),
                    "from_addr": _extract_addr(msg.get("From")),
                    "to_addr": _extract_addr(msg.get("To")),
                    "cc_addr": _extract_addr(msg.get("Cc")),
                    "subject": _decode_str(msg.get("Subject")),
                    "date": dt,
                    "body_text": plain,
                    "body_html": html,
                    "flags": flags,
                })
            except Exception as e:
                # Skip unparseable messages
                continue
        return messages

    def search_server(self, folder: str, criteria: str, limit: int = 50) -> list[dict]:
        """Search on IMAP server using IMAP SEARCH criteria."""
        if not self.conn:
            self.connect()
        status, _ = self.conn.select(folder, readonly=True)
        if status != "OK":
            return []

        status, data = self.conn.search(None, criteria)
        if status != "OK" or not data[0]:
            return []

        uids = data[0].split()
        uids = uids[-limit:] if len(uids) > limit else uids

        messages = []
        for uid in uids:
            try:
                status, msg_data = self.conn.fetch(uid, "(RFC822 FLAGS)")
                if status != "OK":
                    continue
                raw_email = msg_data[0][1]
                flags = _get_flags(msg_data[0])
                msg = email.message_from_bytes(raw_email)
                plain, html = _get_text_body(msg)
                date_str = msg.get("Date", "")
                try:
                    dt = parsedate_to_datetime(date_str).isoformat()
                except Exception:
                    dt = date_str
                messages.append({
                    "message_uid": uid.decode("utf-8", errors="replace") if isinstance(uid, bytes) else str(uid),
                    "from_addr": _extract_addr(msg.get("From")),
                    "to_addr": _extract_addr(msg.get("To")),
                    "cc_addr": _extract_addr(msg.get("Cc")),
                    "subject": _decode_str(msg.get("Subject")),
                    "date": dt,
                    "body_text": plain,
                    "body_html": html,
                    "flags": flags,
                })
            except Exception:
                continue
        return messages


def connect_imap_for_account(account: dict) -> IMAPClient:
    """Create an IMAPClient from an account record (decrypts password)."""
    password = decrypt(account["encrypted_password"])
    username = account.get("username") or account["email_address"]
    return IMAPClient(
        host=account["imap_host"],
        port=account["imap_port"],
        ssl=bool(account["imap_ssl"]),
        username=username,
        password=password,
    )
