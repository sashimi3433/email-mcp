"""SQLite database for accounts, server configs, and cached messages."""

import os
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from .config import DATA_DIR, DB_PATH, DEFAULT_SYNC_LIMIT


def get_db_path() -> str:
    return os.path.expanduser(DB_PATH)


def get_connection() -> sqlite3.Connection:
    db_path = get_db_path()
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db():
    """Create tables if they don't exist."""
    conn = get_connection()
    conn.executescript(SCHEMA)
    conn.close()


SCHEMA = """
-- Reusable server domain configs (e.g. @example.com → IMAP/SMTP settings)
CREATE TABLE IF NOT EXISTS server_domains (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain TEXT NOT NULL UNIQUE,
    imap_host TEXT NOT NULL,
    imap_port INTEGER NOT NULL DEFAULT 993,
    imap_ssl INTEGER NOT NULL DEFAULT 1,
    smtp_host TEXT NOT NULL,
    smtp_port INTEGER NOT NULL DEFAULT 587,
    smtp_ssl INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Email accounts
CREATE TABLE IF NOT EXISTS accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT NOT NULL,
    email_address TEXT NOT NULL UNIQUE,
    username TEXT,
    server_domain_id INTEGER,
    imap_host TEXT,
    imap_port INTEGER DEFAULT 993,
    imap_ssl INTEGER DEFAULT 1,
    smtp_host TEXT,
    smtp_port INTEGER DEFAULT 587,
    smtp_ssl INTEGER DEFAULT 1,
    encrypted_password TEXT NOT NULL,
    last_sync TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (server_domain_id) REFERENCES server_domains(id) ON DELETE SET NULL
);

-- Cached email messages
CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    folder TEXT NOT NULL DEFAULT 'INBOX',
    message_uid TEXT NOT NULL,
    from_addr TEXT,
    to_addr TEXT,
    cc_addr TEXT,
    subject TEXT,
    date TEXT,
    body_text TEXT,
    body_html TEXT,
    flags TEXT DEFAULT '',
    fetched_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(account_id, folder, message_uid),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_messages_account ON messages(account_id, folder);
CREATE INDEX IF NOT EXISTS idx_messages_subject ON messages(subject);
CREATE INDEX IF NOT EXISTS idx_messages_from ON messages(from_addr);
CREATE INDEX IF NOT EXISTS idx_messages_date ON messages(date);
"""


# ─── Server Domain helpers ────────────────────────────────────────────

def list_server_domains() -> list[dict]:
    conn = get_connection()
    rows = conn.execute("SELECT * FROM server_domains ORDER BY domain").fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_server_domain(domain: str) -> Optional[dict]:
    conn = get_connection()
    row = conn.execute("SELECT * FROM server_domains WHERE domain = ?", (domain,)).fetchone()
    conn.close()
    return dict(row) if row else None


def upsert_server_domain(domain: str, imap_host: str, imap_port: int,
                         imap_ssl: bool, smtp_host: str, smtp_port: int,
                         smtp_ssl: bool) -> Optional[int]:
    conn = get_connection()
    existing = conn.execute("SELECT id FROM server_domains WHERE domain = ?", (domain,)).fetchone()
    if existing:
        conn.execute(
            "UPDATE server_domains SET imap_host=?, imap_port=?, imap_ssl=?, smtp_host=?, smtp_port=?, smtp_ssl=? WHERE domain=?",
            (imap_host, imap_port, int(imap_ssl), smtp_host, smtp_port, int(smtp_ssl), domain)
        )
        conn.commit()
        conn.close()
        return existing["id"]
    else:
        cur = conn.execute(
            "INSERT INTO server_domains (domain, imap_host, imap_port, imap_ssl, smtp_host, smtp_port, smtp_ssl) VALUES (?,?,?,?,?,?,?)",
            (domain, imap_host, imap_port, int(imap_ssl), smtp_host, smtp_port, int(smtp_ssl))
        )
        conn.commit()
        conn.close()
        return cur.lastrowid


def delete_server_domain(domain_id: int):
    conn = get_connection()
    conn.execute("DELETE FROM server_domains WHERE id = ?", (domain_id,))
    conn.commit()
    conn.close()


# ─── Account helpers ───────────────────────────────────────────────────

def list_accounts() -> list[dict]:
    conn = get_connection()
    rows = conn.execute("""
        SELECT a.id, a.label, a.email_address, a.username, a.imap_host, a.imap_port, a.imap_ssl,
               a.smtp_host, a.smtp_port, a.smtp_ssl, a.last_sync, a.created_at,
               sd.domain as server_domain
        FROM accounts a
        LEFT JOIN server_domains sd ON a.server_domain_id = sd.id
        ORDER BY a.label
    """).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_account(account_id: int) -> Optional[dict]:
    conn = get_connection()
    row = conn.execute("""
        SELECT a.*, sd.domain as server_domain,
               sd.imap_host as sd_imap_host, sd.imap_port as sd_imap_port, sd.imap_ssl as sd_imap_ssl,
               sd.smtp_host as sd_smtp_host, sd.smtp_port as sd_smtp_port, sd.smtp_ssl as sd_smtp_ssl
        FROM accounts a
        LEFT JOIN server_domains sd ON a.server_domain_id = sd.id
        WHERE a.id = ?
    """, (account_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def create_account(label: str, email_address: str, password: str,
                   imap_host: str, imap_port: int, imap_ssl: bool,
                   smtp_host: str, smtp_port: int, smtp_ssl: bool,
                   username: Optional[str] = None, server_domain_id: Optional[int] = None) -> Optional[int]:
    from .crypto import encrypt
    conn = get_connection()
    encrypted_pw = encrypt(password)
    cur = conn.execute(
        """INSERT INTO accounts (label, email_address, username, encrypted_password,
           imap_host, imap_port, imap_ssl, smtp_host, smtp_port, smtp_ssl, server_domain_id)
           VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
        (label, email_address, username, encrypted_pw,
         imap_host, imap_port, int(imap_ssl), smtp_host, smtp_port, int(smtp_ssl), server_domain_id)
    )
    conn.commit()
    conn.close()
    return cur.lastrowid


def update_account(account_id: int, **kwargs):
    """Update account fields. Password handled separately for re-encryption."""
    from .crypto import encrypt
    conn = get_connection()
    if "password" in kwargs:
        kwargs["encrypted_password"] = encrypt(kwargs.pop("password"))
    sets = []
    vals = []
    for k, v in kwargs.items():
        sets.append(f"{k} = ?")
        vals.append(v)
    vals.append(account_id)
    conn.execute(f"UPDATE accounts SET {', '.join(sets)} WHERE id = ?", vals)
    conn.commit()
    conn.close()


def delete_account(account_id: int):
    conn = get_connection()
    conn.execute("DELETE FROM messages WHERE account_id = ?", (account_id,))
    conn.execute("DELETE FROM accounts WHERE id = ?", (account_id,))
    conn.commit()
    conn.close()


def update_last_sync(account_id: int):
    conn = get_connection()
    now = datetime.now(timezone.utc).isoformat()
    conn.execute("UPDATE accounts SET last_sync = ? WHERE id = ?", (now, account_id))
    conn.commit()
    conn.close()


# ─── Message helpers ────────────────────────────────────────────────────

def save_messages(account_id: int, folder: str, messages: list[dict]):
    """Bulk upsert messages. Each message dict should have: message_uid, from_addr, to_addr, cc_addr, subject, date, body_text, body_html, flags."""
    conn = get_connection()
    now = datetime.now(timezone.utc).isoformat()
    for m in messages:
        conn.execute(
            """INSERT INTO messages (account_id, folder, message_uid, from_addr, to_addr, cc_addr,
               subject, date, body_text, body_html, flags, fetched_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
               ON CONFLICT(account_id, folder, message_uid) DO UPDATE SET
               from_addr=excluded.from_addr, to_addr=excluded.to_addr, cc_addr=excluded.cc_addr,
               subject=excluded.subject, date=excluded.date, body_text=excluded.body_text,
               body_html=excluded.body_html, flags=excluded.flags, fetched_at=excluded.fetched_at""",
            (account_id, folder, m.get("message_uid", ""), m.get("from_addr", ""),
             m.get("to_addr", ""), m.get("cc_addr", ""), m.get("subject", ""),
             m.get("date", ""), m.get("body_text", ""), m.get("body_html", ""),
             m.get("flags", ""), now)
        )
    conn.commit()
    conn.close()


def list_messages(account_id: int, folder: str = "INBOX", limit: int = DEFAULT_SYNC_LIMIT,
                  offset: int = 0) -> list[dict]:
    conn = get_connection()
    rows = conn.execute(
        """SELECT id, folder, message_uid, from_addr, to_addr, cc_addr, subject, date, flags, fetched_at
           FROM messages WHERE account_id = ? AND folder = ? ORDER BY date DESC LIMIT ? OFFSET ?""",
        (account_id, folder, limit, offset)
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_message(account_id: int, message_db_id: int) -> Optional[dict]:
    conn = get_connection()
    row = conn.execute(
        "SELECT * FROM messages WHERE id = ? AND account_id = ?",
        (message_db_id, account_id)
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def search_messages(account_id: int, query: str, folder: Optional[str] = None,
                    limit: int = 50) -> list[dict]:
    conn = get_connection()
    like = f"%{query}%"
    if folder:
        rows = conn.execute(
            """SELECT id, folder, message_uid, from_addr, to_addr, cc_addr, subject, date, flags
               FROM messages WHERE account_id = ? AND folder = ?
               AND (subject LIKE ? OR from_addr LIKE ? OR body_text LIKE ?)
               ORDER BY date DESC LIMIT ?""",
            (account_id, folder, like, like, like, limit)
        ).fetchall()
    else:
        rows = conn.execute(
            """SELECT id, folder, message_uid, from_addr, to_addr, cc_addr, subject, date, flags
               FROM messages WHERE account_id = ?
               AND (subject LIKE ? OR from_addr LIKE ? OR body_text LIKE ?)
               ORDER BY date DESC LIMIT ?""",
            (account_id, like, like, like, limit)
        ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


# ─── Unified inbox (all accounts) ──────────────────────────────────────

def list_all_messages(limit: int = 100, offset: int = 0) -> list[dict]:
    """List messages across all accounts, newest first."""
    conn = get_connection()
    rows = conn.execute(
        """SELECT m.id, m.account_id, m.folder, m.message_uid, m.from_addr, m.to_addr,
                  m.cc_addr, m.subject, m.date, m.flags, m.fetched_at,
                  a.label as account_label, a.email_address as account_email
           FROM messages m
           JOIN accounts a ON m.account_id = a.id
           WHERE m.folder = 'INBOX'
           ORDER BY m.date DESC LIMIT ? OFFSET ?""",
        (limit, offset)
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_all_message(message_db_id: int) -> Optional[dict]:
    """Get a single message by DB id (cross-account)."""
    conn = get_connection()
    row = conn.execute(
        """SELECT m.*, a.label as account_label, a.email_address as account_email
           FROM messages m
           JOIN accounts a ON m.account_id = a.id
           WHERE m.id = ?""",
        (message_db_id,)
    ).fetchone()
    conn.close()
    return dict(row) if row else None
