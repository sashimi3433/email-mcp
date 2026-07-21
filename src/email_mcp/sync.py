"""Email sync: pull messages from IMAP to local SQLite cache."""

import logging
from typing import Optional

from .database import (
    get_account, update_last_sync, save_messages,
    delete_missing_messages,
    list_messages as db_list_messages,
)
from .imap_client import connect_imap_for_account
from .config import DEFAULT_FOLDERS, DEFAULT_SYNC_LIMIT

logger = logging.getLogger(__name__)


def sync_account(account_id: int, folders: Optional[list[str]] = None,
                 limit: int = 0) -> dict:
    """
    Sync emails from an account to local cache.

    Performs a full reconciliation per folder:
      1. Fetch all current UIDs from the IMAP server
      2. Delete local messages whose UIDs no longer exist on the server
      3. Fetch and upsert all current messages

    Args:
        account_id: Account ID
        folders: Folders to sync (None = all server folders)
        limit: Max messages per folder. 0 = ALL messages.

    Returns {success, messages_synced, messages_deleted, folders_synced, errors}.
    """
    account = get_account(account_id)
    if not account:
        return {"success": False, "error": f"Account {account_id} not found"}

    imap_host = account["imap_host"] or account.get("sd_imap_host")
    imap_port = account["imap_port"] or account.get("sd_imap_port")
    imap_ssl = account["imap_ssl"] if account["imap_ssl"] is not None else account.get("sd_imap_ssl", 1)

    if not imap_host:
        return {"success": False, "error": "No IMAP host configured for this account"}

    account["imap_host"] = imap_host
    account["imap_port"] = imap_port
    account["imap_ssl"] = imap_ssl

    target_folders = folders or DEFAULT_FOLDERS
    total_synced = 0
    total_deleted = 0
    synced_folders = []
    errors = []

    client = connect_imap_for_account(account)
    try:
        client.connect()
        available_folders = client.list_folders()
        logger.info(f"Available folders: {available_folders}")

        if target_folders is None:
            target_folders = available_folders

        for folder in target_folders:
            matched = None
            for f in available_folders:
                if f.upper() == folder.upper() or f == folder:
                    matched = f
                    break
            if not matched:
                logger.debug(f"Folder '{folder}' not found, skipping")
                continue

            try:
                # 1. Get current UIDs from server
                server_uids = set(client.get_folder_uids(matched))
                logger.info(f"Server UIDs for '{matched}': {len(server_uids)}")

                # 2. Delete messages no longer on server
                deleted = delete_missing_messages(account_id, matched, server_uids)
                if deleted:
                    logger.info(f"Deleted {deleted} stale messages from '{matched}'")
                total_deleted += deleted

                # 3. Fetch and upsert all current messages
                messages = client.fetch_messages(matched, limit=limit)
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
            "messages_deleted": total_deleted,
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
