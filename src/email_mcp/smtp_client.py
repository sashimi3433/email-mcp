"""SMTP client for sending replies."""

import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.utils import formataddr, parseaddr, make_msgid
from typing import Optional

from .crypto import decrypt


class SMTPClient:
    def __init__(self, host: str, port: int, ssl: bool, username: str, password: str):
        self.host = host
        self.port = port
        self.ssl = ssl
        self.username = username
        self.password = password

    def _connect(self) -> smtplib.SMTP:
        if self.ssl:
            server = smtplib.SMTP_SSL(self.host, self.port, timeout=30)
        else:
            server = smtplib.SMTP(self.host, self.port, timeout=30)
            try:
                server.starttls()
            except smtplib.SMTPNotSupportedError:
                pass
        server.login(self.username, self.password)
        return server

    def send_reply(self, original_to: str, original_subject: str,
                   original_message_id: str, reply_body: str,
                   from_name: Optional[str] = None,
                   from_email: Optional[str] = None,
                   reply_all: bool = False,
                   cc: Optional[str] = None) -> dict:
        """Send a reply email. Returns success dict."""
        if from_email:
            sender = from_email
        else:
            sender = self.username

        if from_name:
            from_header = formataddr((from_name, sender))
        else:
            from_header = sender

        # Build subject with Re: prefix
        subject = original_subject
        if not subject.lower().startswith("re:"):
            subject = f"Re: {subject}"

        # Parse original To to get Reply-To address
        _, orig_addr = parseaddr(original_to)
        to_addr = orig_addr or original_to

        msg = MIMEMultipart("alternative")
        msg["From"] = from_header
        msg["To"] = to_addr
        msg["Subject"] = subject
        msg["In-Reply-To"] = original_message_id
        if original_message_id:
            msg["References"] = original_message_id

        if reply_all and cc:
            msg["Cc"] = cc

        msg.attach(MIMEText(reply_body, "plain", "utf-8"))

        recipients = [to_addr]
        if reply_all and cc:
            recipients.extend([addr.strip() for addr in cc.split(",") if addr.strip()])

        server = self._connect()
        try:
            server.sendmail(sender, recipients, msg.as_string())
            return {"success": True, "to": to_addr, "subject": subject}
        except Exception as e:
            return {"success": False, "error": str(e)}
        finally:
            try:
                server.quit()
            except Exception:
                pass

    def send_mail(self, to: str, subject: str, body: str,
                  from_name: Optional[str] = None,
                  from_email: Optional[str] = None,
                  cc: Optional[str] = None) -> dict:
        """Send a new email. Returns success dict."""
        if from_email:
            sender = from_email
        else:
            sender = self.username

        if from_name:
            from_header = formataddr((from_name, sender))
        else:
            from_header = sender

        msg = MIMEMultipart("alternative")
        msg["From"] = from_header
        msg["To"] = to
        msg["Subject"] = subject

        if cc:
            msg["Cc"] = cc

        msg.attach(MIMEText(body, "plain", "utf-8"))

        recipients = [to]
        if cc:
            recipients.extend([addr.strip() for addr in cc.split(",") if addr.strip()])

        server = self._connect()
        try:
            server.sendmail(sender, recipients, msg.as_string())
            return {"success": True, "to": to, "subject": subject}
        except Exception as e:
            return {"success": False, "error": str(e)}
        finally:
            try:
                server.quit()
            except Exception:
                pass


def connect_smtp_for_account(account: dict) -> SMTPClient:
    """Create an SMTPClient from an account record."""
    password = decrypt(account["encrypted_password"])
    username = account.get("username") or account["email_address"]
    return SMTPClient(
        host=account["smtp_host"],
        port=account["smtp_port"],
        ssl=bool(account["smtp_ssl"]),
        username=username,
        password=password,
    )
