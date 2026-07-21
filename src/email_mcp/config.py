"""Configuration and constants."""

import os

APP_NAME = "email-mcp"
DATA_DIR = os.path.expanduser(os.getenv("EMAIL_MCP_DATA_DIR", "~/.hermes/email-mcp/data"))
DB_PATH = os.path.join(DATA_DIR, "emails.db")
ENCRYPTION_KEY_PATH = os.path.join(DATA_DIR, ".encryption_key")
WEB_UI_PORT = int(os.getenv("EMAIL_MCP_WEB_PORT", "5858"))
WEB_UI_HOST = os.getenv("EMAIL_MCP_WEB_HOST", "0.0.0.0")
DEFAULT_SYNC_LIMIT = 0  # 0 = unlimited (fetch all messages)
DEFAULT_FOLDERS = ["INBOX", "INBOX.Sent", "INBOX.Drafts", "INBOX.Trash", "INBOX.Deleted Messages", "INBOX.spam"]
