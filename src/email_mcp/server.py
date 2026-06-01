"""MCP Server: exposes email tools to AI clients."""

import json
import logging
from mcp.server.fastmcp import FastMCP
from typing import Optional

from .database import (
    init_db, list_accounts, get_account, get_message,
    list_messages as db_list_messages,
    search_messages as db_search_messages,
)
from .sync import sync_account, get_cached_messages
from .smtp_client import connect_smtp_for_account

logger = logging.getLogger(__name__)

mcp = FastMCP("email-mcp", instructions=(
    "Email MCP Server: 自前IMAPメールサーバーのメールをAIから安全に読み書きできるMCPサーバーです。\n"
    "認証情報はすべてローカルで暗号化保存され、AIには一切公開されません。\n"
    "メールの閲覧・検索・返信が可能です。"
))


@mcp.tool()
def list_accounts() -> str:
    """登録済みのメールアカウント一覧を取得する。各アカウントのID、ラベル、メールアドレス、最終同期日時を返す。"""
    accounts = list_accounts()
    if not accounts:
        return json.dumps({"accounts": [], "message": "アカウントが登録されていません。Web UI (http://localhost:5858) から追加してください。"}, ensure_ascii=False)
    result = []
    for a in accounts:
        result.append({
            "id": a["id"],
            "label": a["label"],
            "email": a["email_address"],
            "server_domain": a.get("server_domain", "custom"),
            "last_sync": a.get("last_sync", "未同期"),
        })
    return json.dumps({"accounts": result}, ensure_ascii=False, indent=2)


@mcp.tool()
def list_messages(account_id: int, folder: str = "INBOX", limit: int = 50, offset: int = 0) -> str:
    """指定したアカウントのフォルダからメール一覧を取得する。

    Args:
        account_id: list_accountsで取得したアカウントID
        folder: フォルダ名（デフォルト: INBOX）
        limit: 取得件数（デフォルト: 50）
        offset: オフセット（ページネーション用）
    """
    messages = db_list_messages(account_id, folder, limit, offset)
    if not messages:
        return json.dumps({"messages": [], "message": f"フォルダ '{folder}' にメッセージがありません。sync_accountで同期してください。"}, ensure_ascii=False)
    result = []
    for m in messages:
        result.append({
            "id": m["id"],
            "uid": m["message_uid"],
            "folder": m["folder"],
            "from": m["from_addr"],
            "to": m["to_addr"],
            "subject": m["subject"],
            "date": m["date"],
            "flags": m["flags"],
        })
    return json.dumps({"account_id": account_id, "folder": folder, "count": len(result), "messages": result}, ensure_ascii=False, indent=2)


@mcp.tool()
def get_message(account_id: int, message_id: int) -> str:
    """指定したメールの本文を取得する。

    Args:
        account_id: list_accountsで取得したアカウントID
        message_id: list_messagesで取得したメッセージID（ローカルDBのID）
    """
    msg = get_message(account_id, message_id)
    if not msg:
        return json.dumps({"error": "メッセージが見つかりません"}, ensure_ascii=False)
    return json.dumps({
        "id": msg["id"],
        "folder": msg["folder"],
        "from": msg["from_addr"],
        "to": msg["to_addr"],
        "cc": msg["cc_addr"],
        "subject": msg["subject"],
        "date": msg["date"],
        "body": msg["body_text"],
        "flags": msg["flags"],
    }, ensure_ascii=False, indent=2)


@mcp.tool()
def search_messages(account_id: int, query: str, folder: Optional[str] = None, limit: int = 20) -> str:
    """ローカルにキャッシュされたメールを検索する。件名・送信者・本文から検索。

    Args:
        account_id: list_accountsで取得したアカウントID
        query: 検索キーワード
        folder: 検索対象フォルダ（省略時は全フォルダ）
        limit: 最大件数（デフォルト: 20）
    """
    results = db_search_messages(account_id, query, folder, limit)
    if not results:
        return json.dumps({"query": query, "results": [], "message": "該当するメッセージがありません"}, ensure_ascii=False)
    items = []
    for m in results:
        items.append({
            "id": m["id"],
            "folder": m["folder"],
            "from": m["from_addr"],
            "subject": m["subject"],
            "date": m["date"],
        })
    return json.dumps({"query": query, "count": len(items), "results": items}, ensure_ascii=False, indent=2)


@mcp.tool()
def sync_account_tool(account_id: int, folders: Optional[list[str]] = None, limit: int = 100) -> str:
    """指定したアカウントのメールをIMAPサーバーからローカルに同期する。

    Args:
        account_id: list_accountsで取得したアカウントID
        folders: 同期するフォルダのリスト（省略時はデフォルトフォルダ: INBOX, Sent, Drafts, Trash, Junk）
        limit: フォルダごとの最大取得件数（デフォルト: 100）
    """
    result = sync_account(account_id, folders, limit)
    return json.dumps(result, ensure_ascii=False, indent=2)


@mcp.tool()
def send_reply(account_id: int, message_id: int, body: str, reply_all: bool = False) -> str:
    """指定したメールに対して返信を送信する。SMTP経由で送信されます。

    Args:
        account_id: list_accountsで取得したアカウントID
        message_id: 返信先のメッセージID
        body: 返信本文
        reply_all: 全員に返信する場合true
    """
    account = get_account(account_id)
    if not account:
        return json.dumps({"error": f"アカウント {account_id} が見つかりません"}, ensure_ascii=False)

    msg = get_message(account_id, message_id)
    if not msg:
        return json.dumps({"error": "返信先のメッセージが見つかりません"}, ensure_ascii=False)

    # Resolve SMTP settings
    smtp_host = account["smtp_host"] or account.get("sd_smtp_host")
    smtp_port = account["smtp_port"] or account.get("sd_smtp_port")
    smtp_ssl = account["smtp_ssl"] if account["smtp_ssl"] is not None else account.get("sd_smtp_ssl", 1)

    if not smtp_host:
        return json.dumps({"error": "SMTPホストが設定されていません"}, ensure_ascii=False)

    account["smtp_host"] = smtp_host
    account["smtp_port"] = smtp_port
    account["smtp_ssl"] = smtp_ssl

    smtp = connect_smtp_for_account(account)
    # Construct a synthetic Message-ID for In-Reply-To
    synthetic_mid = f"<{msg['message_uid']}@local>"

    result = smtp.send_reply(
        original_to=msg["from_addr"],
        original_subject=msg["subject"],
        original_message_id=synthetic_mid,
        reply_body=body,
        reply_all=reply_all,
        cc=msg.get("cc_addr") or None,
    )
    return json.dumps(result, ensure_ascii=False, indent=2)


@mcp.tool()
def send_mail(account_id: int, to: str, subject: str, body: str, cc: Optional[str] = None) -> str:
    """新規メールを送信する。

    Args:
        account_id: list_accountsで取得したアカウントID
        to: 送信先メールアドレス
        subject: 件名
        body: 本文
        cc: CCアドレス（省略可）
    """
    account = get_account(account_id)
    if not account:
        return json.dumps({"error": f"アカウント {account_id} が見つかりません"}, ensure_ascii=False)

    smtp_host = account["smtp_host"] or account.get("sd_smtp_host")
    smtp_port = account["smtp_port"] or account.get("sd_smtp_port")
    smtp_ssl = account["smtp_ssl"] if account["smtp_ssl"] is not None else account.get("sd_smtp_ssl", 1)

    if not smtp_host:
        return json.dumps({"error": "SMTPホストが設定されていません"}, ensure_ascii=False)

    account["smtp_host"] = smtp_host
    account["smtp_port"] = smtp_port
    account["smtp_ssl"] = smtp_ssl

    smtp = connect_smtp_for_account(account)
    result = smtp.send_mail(
        to=to, subject=subject, body=body,
        cc=cc,
    )
    return json.dumps(result, ensure_ascii=False, indent=2)


def run_server():
    """Initialize DB and start the MCP server."""
    init_db()
    mcp.run()
