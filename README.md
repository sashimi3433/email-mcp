# 📧 Email MCP

**Self-hosted email for AI.** An MCP (Model Context Protocol) server that gives AI assistants safe, read-oriented access to your IMAP mailboxes — with a Flutter management app for iOS, Android, and macOS.

Passwords are encrypted at rest with AES-256. AI clients never see credentials; they only interact through scoped MCP tools.

> 📖 **日本語ドキュメント**: [README.ja.md](docs/README.ja.md) | [アーキテクチャ](docs/ARCHITECTURE.ja.md) | [Flutterアプリ](docs/APP.ja.md)

## ✨ Features

- **MCP Server** — Exposes email tools (list, read, search, sync) to any MCP-compatible AI client
- **IMAP Sync** — Fetches all messages from all folders into a local SQLite cache (no per-request IMAP round-trips)
- **REST API** — Flask-based API for programmatic access and the Flutter app
- **Web UI** — Built-in account management interface
- **Flutter App** — Native iOS / Android / macOS app with:
  - Unified inbox across all accounts
  - Per-account folder browsing
  - Full-text search
  - Pull-to-refresh, account CRUD, sync management
- **Security** — AES-256-GCM encrypted password storage, credentials never exposed to AI

## 🚀 Quick Start

### Option A: Docker (Recommended)

```bash
git clone https://github.com/sashimi3433/email-mcp.git
cd email-mcp
docker compose up -d
```

That's it. Web UI is at `http://localhost:5858`.

Data (SQLite DB + encryption key) persists in a Docker volume (`email-mcp-data`).

### Option B: Local Install (uv)

#### Prerequisites

- Python 3.11+
- [uv](https://docs.astral.sh/uv/) (recommended) or pip
- An IMAP/SMTP email account (self-hosted, Gmail with app password, etc.)

#### Install

```bash
git clone https://github.com/sashimi3433/email-mcp.git
cd email-mcp
uv sync
```

#### Start the Web UI (account management)

```bash
uv run email-mcp-ui
```

Open `http://localhost:5858` to add your email accounts. Passwords are encrypted on save.

### Start the MCP Server

```bash
uv run email-mcp-server
```

Add to your MCP client config (e.g. Claude Desktop `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "email": {
      "command": "uv",
      "args": ["run", "--directory", "/path/to/email-mcp", "email-mcp-server"]
    }
  }
}
```

Or with `uvx`:
```json
{
  "mcpServers": {
    "email": {
      "command": "uvx",
      "args": ["email-mcp-server"]
    }
  }
}
```

## 📱 Flutter App

The Flutter app connects to the REST API for native mobile/desktop access.

```bash
cd app
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release --split-per-abi
```

**App features:**
- 🔀 Unified inbox — all accounts in one timeline
- 📂 Per-account folder browsing with cached counts
- 🔍 Full-text search across subject / sender / body
- 🔄 Pull-to-refresh + one-tap sync
- ⚙️ Server settings configurable in-app

## 🛠️ MCP Tools

| Tool | Description |
|---|---|
| `list_accounts` | List registered email accounts |
| `list_messages` | List messages in a folder (paginated) |
| `get_message` | Get full message body by ID |
| `search_messages` | Full-text search across cached messages |
| `sync_account` | Sync messages from IMAP server to local cache |
| `send_reply` | Reply to a message via SMTP |
| `send_mail` | Send a new email via SMTP |

## 🏗️ Architecture

```
┌──────────────┐     MCP/stdio      ┌──────────────┐
│  AI Client   │ ◄────────────────► │  MCP Server  │
│  (Claude等)  │                    │  (server.py) │
└──────────────┘                    └──────┬───────┘
                                           │
┌──────────────┐    REST API        ┌──────▼───────┐     IMAP/SMTP     ┌──────────┐
│  Flutter App │ ◄────────────────► │  Flask Web   │ ◄───────────────► │  Mail    │
│  (iOS/Android)│   HTTP :5858      │  (web_ui.py) │                   │  Server  │
└──────────────┘                    └──────┬───────┘                   └──────────┘
                                           │
                                    ┌──────▼───────┐
                                    │   SQLite     │
                                    │  (encrypted) │
                                    └──────────────┘
```

## 📁 Project Structure

```
email-mcp/
├── src/email_mcp/          # Python backend
│   ├── server.py           # MCP server — AI tools
│   ├── web_ui.py           # Flask REST API + Web UI
│   ├── database.py         # SQLite data layer
│   ├── imap_client.py      # IMAP fetch (UID-based, batched)
│   ├── smtp_client.py      # SMTP send
│   ├── sync.py             # Sync orchestration
│   ├── crypto.py           # AES-256-GCM encryption
│   └── config.py           # Configuration
├── app/                    # Flutter management app
│   └── lib/
│       ├── models/         # Data models
│       ├── screens/        # UI screens
│       └── services/       # API client
├── pyproject.toml
├── LICENSE
└── README.md
```

## 🔒 Security

- Email passwords are encrypted with **AES-256-GCM** before storing in SQLite
- The encryption key is stored in `data/.encryption_key` (gitignored, never committed)
- AI clients access email through MCP tools only — they **never** see raw credentials
- All data stays on your machine; no cloud, no telemetry

## ⚙️ Configuration

Environment variables:

| Variable | Default | Description |
|---|---|---|
| `EMAIL_MCP_WEB_HOST` | `0.0.0.0` | Web UI bind address |
| `EMAIL_MCP_WEB_PORT` | `5858` | Web UI port |

## 📄 License

[MIT](LICENSE) — © 2026 sashimi3433

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and feature requests welcome on [Issues](https://github.com/sashimi3433/email-mcp/issues).
