"""Flask Web UI + REST API for Email MCP account management."""

import json
import logging
from flask import Flask, render_template, request, jsonify, redirect, url_for

from .database import (
    init_db, list_accounts, get_account, delete_account,
    list_server_domains, get_server_domain, upsert_server_domain,
    delete_server_domain, create_account, update_account,
    list_messages as db_list_messages,
    get_message as db_get_message,
    search_messages as db_search_messages,
    list_all_messages as db_list_all_messages,
    get_all_message as db_get_all_message,
)
from .sync import sync_account
from .smtp_client import connect_smtp_for_account
from .config import WEB_UI_PORT, WEB_UI_HOST

logger = logging.getLogger(__name__)

app = Flask(__name__,
            template_folder="templates",
            static_folder="static")
app.secret_key = "email-mcp-web-ui-secret"


@app.route("/")
@app.route("/<path:spa_path>")
def index(spa_path=None):
    """Serve the SPA for all non-API routes (History API support)."""
    # Only serve SPA for known views; let 404 handle unknown paths
    if spa_path and spa_path not in ("inbox", "accounts", "domains", "search"):
        from werkzeug.exceptions import NotFound
        raise NotFound()
    accounts = list_accounts()
    domains = list_server_domains()
    return render_template("index.html", accounts=accounts, domains=domains)


# ─── Server Domain API ────────────────────────────────────────────────

@app.route("/api/domains", methods=["GET"])
def api_list_domains():
    return jsonify(list_server_domains())


@app.route("/api/domains", methods=["POST"])
def api_create_domain():
    data = request.json
    domain_id = upsert_server_domain(
        domain=data["domain"],
        imap_host=data["imap_host"],
        imap_port=data.get("imap_port", 993),
        imap_ssl=data.get("imap_ssl", True),
        smtp_host=data["smtp_host"],
        smtp_port=data.get("smtp_port", 587),
        smtp_ssl=data.get("smtp_ssl", True),
    )
    return jsonify({"success": True, "id": domain_id})


@app.route("/api/domains/<int:domain_id>", methods=["GET"])
def api_get_domain(domain_id):
    conn = __import__("sqlite3").connect(":memory:")
    conn.close()
    domains = list_server_domains()
    for d in domains:
        if d["id"] == domain_id:
            return jsonify(d)
    return jsonify({"error": "Not found"}), 404


@app.route("/api/domains/<int:domain_id>", methods=["DELETE"])
def api_delete_domain(domain_id):
    delete_server_domain(domain_id)
    return jsonify({"success": True})


@app.route("/api/domains/lookup", methods=["POST"])
def api_lookup_domain():
    """Look up a server domain config by domain name."""
    data = request.json or {}
    domain = data.get("domain", "")
    if not domain:
        return jsonify({"found": False})
    # Extract domain from email address if full email given
    if "@" in domain:
        domain = domain.split("@")[1]
    config = get_server_domain(domain)
    if config:
        return jsonify({"found": True, "config": config})
    return jsonify({"found": False})


# ─── Account API ───────────────────────────────────────────────────────

@app.route("/api/accounts", methods=["GET"])
def api_list_accounts():
    return jsonify(list_accounts())


@app.route("/api/accounts", methods=["POST"])
def api_create_account():
    data = request.json
    try:
        # If server_domain_id provided, fill in host settings from domain
        server_domain_id = data.get("server_domain_id")
        if server_domain_id:
            # Resolve domain settings
            for d in list_server_domains():
                if d["id"] == server_domain_id:
                    data.setdefault("imap_host", d["imap_host"])
                    data.setdefault("imap_port", d["imap_port"])
                    data.setdefault("imap_ssl", d["imap_ssl"])
                    data.setdefault("smtp_host", d["smtp_host"])
                    data.setdefault("smtp_port", d["smtp_port"])
                    data.setdefault("smtp_ssl", d["smtp_ssl"])
                    break

        account_id = create_account(
            label=data["label"],
            email_address=data["email_address"],
            password=data["password"],
            imap_host=data["imap_host"],
            imap_port=data.get("imap_port", 993),
            imap_ssl=data.get("imap_ssl", True),
            smtp_host=data["smtp_host"],
            smtp_port=data.get("smtp_port", 587),
            smtp_ssl=data.get("smtp_ssl", True),
            username=data.get("username"),
            server_domain_id=server_domain_id,
        )
        return jsonify({"success": True, "id": account_id})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400


@app.route("/api/accounts/<int:account_id>", methods=["GET"])
def api_get_account(account_id):
    account = get_account(account_id)
    if not account:
        return jsonify({"error": "Not found"}), 404
    # Don't expose encrypted password
    account.pop("encrypted_password", None)
    return jsonify(account)


@app.route("/api/accounts/<int:account_id>", methods=["DELETE"])
def api_delete_account(account_id):
    delete_account(account_id)
    return jsonify({"success": True})


@app.route("/api/accounts/<int:account_id>", methods=["PATCH"])
def api_update_account(account_id):
    data = request.json
    allowed = ["label", "username", "imap_host", "imap_port", "imap_ssl",
               "smtp_host", "smtp_port", "smtp_ssl"]
    updates = {k: v for k, v in data.items() if k in allowed}
    if "password" in data:
        updates["password"] = data["password"]
    if updates:
        update_account(account_id, **updates)
    return jsonify({"success": True})


# ─── Message API ───────────────────────────────────────────────────────

@app.route("/api/accounts/<int:account_id>/messages", methods=["GET"])
def api_list_messages(account_id):
    folder = request.args.get("folder", "INBOX")
    limit = int(request.args.get("limit", 50))
    offset = int(request.args.get("offset", 0))
    messages = db_list_messages(account_id, folder, limit, offset)
    return jsonify({"account_id": account_id, "folder": folder,
                    "count": len(messages), "messages": messages})


@app.route("/api/accounts/<int:account_id>/messages/<int:message_id>", methods=["GET"])
def api_get_message(account_id, message_id):
    msg = db_get_message(account_id, message_id)
    if not msg:
        return jsonify({"error": "Not found"}), 404
    return jsonify(msg)


@app.route("/api/accounts/<int:account_id>/messages/<int:message_id>/reply", methods=["POST"])
def api_reply_message(account_id, message_id):
    """Send a reply to a specific message via SMTP."""
    data = request.json or {}
    body = data.get("body", "")
    reply_all = data.get("reply_all", False)
    if not body:
        return jsonify({"success": False, "error": "body is required"}), 400

    account = get_account(account_id)
    if not account:
        return jsonify({"success": False, "error": "Account not found"}), 404

    msg = db_get_message(account_id, message_id)
    if not msg:
        return jsonify({"success": False, "error": "Message not found"}), 404

    # Resolve SMTP settings
    smtp_host = account["smtp_host"] or account.get("sd_smtp_host")
    smtp_port = account["smtp_port"] or account.get("sd_smtp_port")
    smtp_ssl = account["smtp_ssl"] if account["smtp_ssl"] is not None else account.get("sd_smtp_ssl", 1)

    if not smtp_host:
        return jsonify({"success": False, "error": "SMTP host not configured"}), 400

    account["smtp_host"] = smtp_host
    account["smtp_port"] = smtp_port
    account["smtp_ssl"] = smtp_ssl

    smtp = connect_smtp_for_account(account)
    synthetic_mid = f"<{msg['message_uid']}@local>"

    result = smtp.send_reply(
        original_to=msg["from_addr"],
        original_subject=msg["subject"],
        original_message_id=synthetic_mid,
        reply_body=body,
        reply_all=reply_all,
        cc=msg.get("cc_addr") or None,
    )
    return jsonify(result)


@app.route("/api/accounts/<int:account_id>/send", methods=["POST"])
def api_send_mail(account_id):
    """Send a new email via SMTP."""
    data = request.json or {}
    to = data.get("to", "")
    subject = data.get("subject", "")
    body = data.get("body", "")
    cc = data.get("cc")

    if not to or not subject or not body:
        return jsonify({"success": False, "error": "to, subject, body are required"}), 400

    account = get_account(account_id)
    if not account:
        return jsonify({"success": False, "error": "Account not found"}), 404

    smtp_host = account["smtp_host"] or account.get("sd_smtp_host")
    smtp_port = account["smtp_port"] or account.get("sd_smtp_port")
    smtp_ssl = account["smtp_ssl"] if account["smtp_ssl"] is not None else account.get("sd_smtp_ssl", 1)

    if not smtp_host:
        return jsonify({"success": False, "error": "SMTP host not configured"}), 400

    account["smtp_host"] = smtp_host
    account["smtp_port"] = smtp_port
    account["smtp_ssl"] = smtp_ssl

    smtp = connect_smtp_for_account(account)
    result = smtp.send_mail(to=to, subject=subject, body=body, cc=cc)
    return jsonify(result)


# ─── Search API ────────────────────────────────────────────────────────

@app.route("/api/accounts/<int:account_id>/search", methods=["GET"])
def api_search_messages(account_id):
    query = request.args.get("q", "")
    folder = request.args.get("folder")
    limit = int(request.args.get("limit", 20))
    if not query:
        return jsonify({"query": "", "results": [], "message": "Query is required"})
    results = db_search_messages(account_id, query, folder, limit)
    return jsonify({"query": query, "count": len(results), "results": results})


# ─── Sync API ──────────────────────────────────────────────────────────

@app.route("/api/accounts/<int:account_id>/sync", methods=["POST"])
def api_sync_account(account_id):
    data = request.json or {}
    result = sync_account(account_id, folders=data.get("folders"), limit=data.get("limit", 0))
    return jsonify(result)


# ─── Folders API ───────────────────────────────────────────────────────

@app.route("/api/accounts/<int:account_id>/folders", methods=["GET"])
def api_list_folders(account_id):
    """List available IMAP folders by checking distinct folders in cache or connecting live."""
    from .database import get_connection
    conn = get_connection()
    try:
        rows = conn.execute(
            "SELECT DISTINCT folder, COUNT(*) as count FROM messages WHERE account_id = ? GROUP BY folder ORDER BY folder",
            (account_id,)
        ).fetchall()
        folders = [{"name": r["folder"], "cached_count": r["count"]} for r in rows]
        return jsonify({"account_id": account_id, "folders": folders})
    finally:
        conn.close()


# ─── Unified Inbox API (all accounts) ──────────────────────────────────

@app.route("/api/messages", methods=["GET"])
def api_list_all_messages():
    """List messages across all accounts (INBOX only), newest first."""
    limit = int(request.args.get("limit", 100))
    offset = int(request.args.get("offset", 0))
    messages = db_list_all_messages(limit, offset)
    return jsonify({"count": len(messages), "messages": messages})


@app.route("/api/messages/<int:message_id>", methods=["GET"])
def api_get_unified_message(message_id):
    """Get a single message by DB id (cross-account)."""
    msg = db_get_all_message(message_id)
    if not msg:
        return jsonify({"error": "Not found"}), 404
    return jsonify(msg)


# ─── Health / Info ─────────────────────────────────────────────────────

@app.route("/api/health", methods=["GET"])
def api_health():
    return jsonify({"status": "ok", "service": "email-mcp", "version": "0.2.0"})


def run_web(host: str = WEB_UI_HOST, port: int = WEB_UI_PORT):
    """Start the web UI server."""
    init_db()
    logger.info(f"Email MCP Web UI starting at http://{host}:{port}")
    app.run(host=host, port=port, debug=False, use_reloader=False)
