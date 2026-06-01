"""Email sync: pull messages from IMAP to local SQLite cache."""

import logging
from typing import Optional

from .database import (
    get_account, update_last_sync, save_messages,
    list_messages as db_list_messages,
)
from .imap_client import connect_imap_for_account
from .config import DEFAULT_FOLDERS, DEFAULT_SYNC_LIMIT

logger = logging.getLogger(__name__)


def sync_account(account_id: int, folders: Optional[list[str]] = None,
                 limit: int = DEFAULT_SYNC_LIMIT) -> dict:
    """
    Sync emails from an account to local cache.
    Returns {success, messages_synced, folders_synced, errors}.
    """
    account = get_account(account_id)
    if not account:
        return {"success": False, "error": f"Account {account_id} not found"}

    # Resolve IMAP settings (account-level overrides domain-level)
    imap_host = account["imap_host"] or account.get("sd_imap_host")
    imap_port = account["imap_port"] or account.get("sd_imap_port")
    imap_ssl = account["imap_ssl"] if account["imap_ssl"] is not None else account.get("sd_imap_ssl", 1)

    if not imap_host:
        return {"success": False, "error": "No IMAP host configured for this account"}

    # Patch account for connect function
    account["imap_host"] = imap_host
    account["imap_port"] = imap_port
    account["imap_ssl"] = imap_ssl

    target_folders = folders or DEFAULT_FOLDERS
    total_synced = 0
    synced_folders = []
    errors = []

    client = connect_imap_for_account(account)
    try:
        client.connect()
        # Get actual folder list
        available_folders = client.list_folders()
        logger.info(f"Available folders: {available_folders}")

        for folder in target_folders:
            # Try exact match first, then case-insensitive
            matched = None
            for f in available_folders:
                if f.upper() == folder.upper() or f == folder:
                    matched = f
                    break
            if not matched:
                logger.debug(f"Folder '{folder}' not found, skipping")
                continue

            try:
                messages = client.fetch_messages(matched, limit)
                if messages:
                    save_messages(account_id, matched, messages)
                synced_folders.append(matched)
                total_synced += len(messages)
                logger.info(f"Synced {len(messages)} messages from '{matched}'")
            except Exception as e:
                errors.append(f"{folder}: {str(e)}")
                logger.error(f"Error syncing folder '{folder}': {e}")

        update_last_sync(account_id)
        return {
            "success": True,
            "account": account["email_address"],
            "messages_synced": total_synced,
            "folders_synced": synced_folders,
            "errors": errors,
        }
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        client.disconnect()


def get_cached_messages(account_id: int, folder: str = "INBOX",
                         limit: int = DEFAULT_SYNC_LIMIT, offset: int = 0) -> list[dict]:
    """Get messages from local cache only."""
    return db_list_messages(account_id, folder, limit, offset)
