"""IMAP client for fetching and searching emails."""

import imaplib
import email
from email.header import decode_header
from email.message import Message as EmailMessage
from email.utils import parseaddr, parsedate_to_datetime
from typing import Optional
import html2text
import re
import logging

from .crypto import decrypt

logger = logging.getLogger(__name__)


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
        if isinstance(item, tuple):
            # (metadata, data) tuple from UID FETCH
            meta = item[0]
            if isinstance(meta, bytes) and b"FLAGS" in meta:
                # Extract flags from metadata like b'1 (UID 1 FLAGS (\\Seen))'
                flags_match = re.search(rb'FLAGS \(([^)]*)\)', meta)
                if flags_match:
                    return f"({flags_match.group(1).decode('utf-8', errors='replace')})"
    return ""


def _parse_one_message(uid: bytes, msg_data: list) -> Optional[dict]:
    """Parse a single FETCH response into a message dict."""
    raw_email = None
    flags = ""
    for item in msg_data:
        if isinstance(item, tuple):
            meta = item[0]
            data = item[1]
            if isinstance(meta, bytes) and b"FLAGS" in meta:
                flags_match = re.search(rb'FLAGS \(([^)]*)\)', meta)
                if flags_match:
                    flags = f"({flags_match.group(1).decode('utf-8', errors='replace')})"
            if isinstance(data, bytes):
                raw_email = data
        elif isinstance(item, bytes):
            if b"FLAGS" in item:
                flags_match = re.search(rb'FLAGS \(([^)]*)\)', item)
                if flags_match:
                    flags = f"({flags_match.group(1).decode('utf-8', errors='replace')})"
    if not raw_email:
        return None

    msg = email.message_from_bytes(raw_email)
    plain, html = _get_text_body(msg)
    date_str = msg.get("Date", "")
    try:
        dt = parsedate_to_datetime(date_str).isoformat()
    except Exception:
        dt = date_str
    return {
        "message_uid": uid.decode("utf-8", errors="replace") if isinstance(uid, bytes) else str(uid),
        "from_addr": _extract_addr(msg.get("From")),
        "to_addr": _extract_addr(msg.get("To")),
        "cc_addr": _extract_addr(msg.get("Cc")),
        "subject": _decode_str(msg.get("Subject")),
        "date": dt,
        "body_text": plain,
        "body_html": html,
        "flags": flags,
    }


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
                    parts = raw.split('"')
                    if len(parts) >= 3:
                        folder = parts[-2]
                        folders.append(folder)
        return folders

    def fetch_messages(self, folder: str, limit: int = 0) -> list[dict]:
        """Fetch messages from a folder using UID FETCH for stability.

        Args:
            folder: Folder name to fetch from
            limit: Max messages to fetch. 0 = all messages.
                   Positive = most recent N by UID.
        """
        if not self.conn:
            self.connect()
        status, _ = self.conn.select(folder, readonly=True)
        if status != "OK":
            return []

        # Use UID SEARCH to get all UIDs (stable across sessions)
        status, data = self.conn.uid("search", None, "ALL")
        if status != "OK" or not data[0]:
            return []

        all_uids = data[0].split()
        # Sort by UID ascending (oldest first); most recent are at the end
        all_uids.sort(key=lambda x: int(x))

        if limit and limit > 0 and len(all_uids) > limit:
            # Take the most recent `limit` UIDs
            uids_to_fetch = all_uids[-limit:]
        else:
            uids_to_fetch = all_uids

        total = len(uids_to_fetch)
        logger.info(f"Fetching {total} messages from '{folder}' (total in folder: {len(all_uids)})")

        messages = []
        # Fetch in batches of 50 to avoid timeouts on large folders
        batch_size = 50
        for batch_start in range(0, total, batch_size):
            batch_end = min(batch_start + batch_size, total)
            batch = uids_to_fetch[batch_start:batch_end]

            # Build UID range string for batch fetch
            uid_set = b",".join(batch)

            try:
                status, msg_data = self.conn.uid("fetch", uid_set, "(UID FLAGS RFC822)")
                if status != "OK":
                    logger.warning(f"Batch fetch failed for UIDs {batch_start}-{batch_end}")
                    continue

                # Parse responses - msg_data is a list of tuples (metadata, data) interleaved with b")"
                i = 0
                while i < len(msg_data):
                    item = msg_data[i]
                    if isinstance(item, tuple) and len(item) >= 2:
                        meta = item[0]
                        raw = item[1]
                        if isinstance(meta, bytes) and isinstance(raw, bytes):
                            # Extract UID from metadata
                            uid_match = re.search(rb'UID (\d+)', meta)
                            uid_bytes = uid_match.group(1) if uid_match else b"?"

                            parsed = _parse_one_message(uid_bytes, [item])
                            if parsed:
                                messages.append(parsed)
                    i += 1

                logger.info(f"Fetched batch {batch_start}-{batch_end}/{total} from '{folder}'")
            except Exception as e:
                logger.error(f"Error fetching batch {batch_start}-{batch_end}: {e}")
                # Fallback: fetch one by one
                for uid in batch:
                    try:
                        status, single_data = self.conn.uid("fetch", uid, "(UID FLAGS RFC822)")
                        if status == "OK" and single_data:
                            parsed = _parse_one_message(uid, single_data)
                            if parsed:
                                messages.append(parsed)
                    except Exception as e2:
                        logger.error(f"Error fetching UID {uid}: {e2}")
                        continue

        logger.info(f"Successfully fetched {len(messages)}/{total} messages from '{folder}'")
        return messages

    def search_server(self, folder: str, criteria: str, limit: int = 50) -> list[dict]:
        """Search on IMAP server using IMAP SEARCH criteria."""
        if not self.conn:
            self.connect()
        status, _ = self.conn.select(folder, readonly=True)
        if status != "OK":
            return []

        status, data = self.conn.uid("search", None, criteria)
        if status != "OK" or not data[0]:
            return []

        uids = data[0].split()
        uids.sort(key=lambda x: int(x))
        if limit and limit > 0 and len(uids) > limit:
            uids = uids[-limit:]

        messages = []
        for uid in uids:
            try:
                status, msg_data = self.conn.uid("fetch", uid, "(UID FLAGS RFC822)")
                if status != "OK":
                    continue
                parsed = _parse_one_message(uid, msg_data)
                if parsed:
                    messages.append(parsed)
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
