"""Flask Web UI for Email MCP account management."""

import json
import logging
from flask import Flask, render_template, request, jsonify, redirect, url_for

from .database import (
    init_db, list_accounts, get_account, delete_account,
    list_server_domains, get_server_domain, upsert_server_domain,
    delete_server_domain, create_account, update_account,
)
from .sync import sync_account
from .config import WEB_UI_PORT, WEB_UI_HOST

logger = logging.getLogger(__name__)

app = Flask(__name__,
            template_folder="templates",
            static_folder="static")
app.secret_key = "email-mcp-web-ui-secret"


@app.route("/")
def index():
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


@app.route("/api/domains/<int:domain_id>", methods=["DELETE"])
def api_delete_domain(domain_id):
    delete_server_domain(domain_id)
    return jsonify({"success": True})


# ─── Account API ───────────────────────────────────────────────────────

@app.route("/api/accounts", methods=["GET"])
def api_list_accounts():
    return jsonify(list_accounts())


@app.route("/api/accounts", methods=["POST"])
def api_create_account():
    data = request.json
    try:
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
            server_domain_id=data.get("server_domain_id"),
        )
        return jsonify({"success": True, "id": account_id})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 400


@app.route("/api/accounts/<int:account_id>", methods=["DELETE"])
def api_delete_account(account_id):
    delete_account(account_id)
    return jsonify({"success": True})


@app.route("/api/accounts/<int:account_id>", methods=["PATCH"])
def api_update_account(account_id):
    data = request.json
    allowed = ["label", "username"]
    updates = {k: v for k, v in data.items() if k in allowed}
    if "password" in data:
        updates["password"] = data["password"]
    if updates:
        update_account(account_id, **updates)
    return jsonify({"success": True})


# ─── Sync API ──────────────────────────────────────────────────────────

@app.route("/api/accounts/<int:account_id>/sync", methods=["POST"])
def api_sync_account(account_id):
    data = request.json or {}
    result = sync_account(account_id, folders=data.get("folders"), limit=data.get("limit", 100))
    return jsonify(result)


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


def run_web(host: str = WEB_UI_HOST, port: int = WEB_UI_PORT):
    """Start the web UI server."""
    init_db()
    logger.info(f"Email MCP Web UI starting at http://{host}:{port}")
    app.run(host=host, port=port, debug=False, use_reloader=False)
