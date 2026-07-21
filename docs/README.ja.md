# 📧 Email MCP

**AIのためのセルフホストメール。** IMAPメールボックスへのAIクライアント向け安全なアクセスを提供するMCP（Model Context Protocol）サーバーと、iOS・Android・macOS対応のFlutter管理アプリ。

パスワードはAES-256でローカル暗号化保存され、AIには一切公開されません。AIはスコープ付きMCPツール経由でのみメールにアクセスします。

## ✨ 特徴

- **MCPサーバー** — メールツール（一覧・読込・検索・同期）をMCP互換AIクライアントに提供
- **IMAP同期** — 全フォルダの全メッセージをローカルSQLiteキャッシュに取得（都度IMAP通信なし）
- **双方向同期** — サーバーで削除されたメールはローカルからも自動削除
- **REST API** — Flutterアプリや外部プログラムから利用可能なFlask API
- **Web UI** — ブラウザベースのアカウント管理画面（初期設定用）
- **Flutterアプリ** — iOS / Android / macOS ネイティブアプリ
  - 全アカウント統合inbox
  - アカウント別フォルダブラウジング
  - 全文検索
  - プル・ツー・リフレッシュ、アカウントCRUD、同期管理
- **セキュリティ** — AES-256-GCM暗号化パスワード保存、認証情報はAIに非公開

## 🚀 クイックスタート

### 方法A: Docker（推奨）

```bash
git clone https://github.com/sashimi3433/email-mcp.git
cd email-mcp
docker compose up -d
```

これだけで `http://localhost:5858` でWeb UI・REST APIが起動します。

データ（SQLite DB・暗号化キー）はDockerボリューム（`email-mcp-data`）に永続化されます。

### 方法B: ローカルインストール（uv）

#### 前提条件

- Python 3.11以上
- [uv](https://docs.astral.sh/uv/)（推奨）または pip
- IMAP/SMTPメールアカウント（セルフホスト、Gmailアプリパスワード等）

#### インストール

```bash
git clone https://github.com/sashimi3433/email-mcp.git
cd email-mcp
uv sync
```

#### Web UIの起動（アカウント管理）

```bash
uv run email-mcp-ui
```

`http://localhost:5858` をブラウザで開き、メールアカウントを追加します。パスワードは保存時に暗号化されます。

#### MCPサーバーの起動

```bash
uv run email-mcp-server
```

MCPクライアント設定（例: Claude Desktop `claude_desktop_config.json`）に追加:

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

## 📱 Flutterアプリ

FlutterアプリはREST APIに接続してネイティブモバイル/デスクトップでメールを閲覧します。

```bash
cd app
flutter pub get

# 接続先デバイスで実行
flutter run

# リリースAPKをビルド
flutter build apk --release --split-per-abi
```

**アプリ機能:**
- 🔀 統合inbox — 全アカウントのメールを1つのタイムラインに統合
- 📂 アカウント別フォルダブラウジング（キャッシュ件数表示付き）
- 🔍 件名・差出人・本文の全文検索
- 🔄 プル・ツー・リフレッシュ + ワンタップ同期
- ⚙️ アプリ内でサーバー設定変更可能

> **注意:** スマホからアクセスする場合、サーバーと同じネットワークまたはVPN（Headscale等）で接続する必要があります。アプリの「設定」タブからサーバーアドレスを変更できます。

## 🛠️ MCPツール一覧

| ツール | 説明 |
|---|---|
| `list_accounts` | 登録済みメールアカウントの一覧を取得 |
| `list_messages` | フォルダ内のメッセージ一覧を取得（ページネーション対応） |
| `get_message` | メッセージIDから本文を取得 |
| `search_messages` | キャッシュ内の全文検索（件名・差出人・本文） |
| `sync_account` | IMAPサーバーからローカルキャッシュへ同期（削除反映あり） |
| `send_reply` | メールに返信（SMTP経由） |
| `send_mail` | 新規メール送信（SMTP経由） |

## 🏗️ アーキテクチャ

```
┌──────────────┐     MCP/stdio      ┌──────────────┐
│  AIクライアント│ ◄────────────────► │  MCPサーバー  │
│  (Claude等)  │                    │  (server.py) │
└──────────────┘                    └──────┬───────┘
                                           │
┌──────────────┐    REST API        ┌──────▼───────┐     IMAP/SMTP     ┌──────────┐
│  Flutterアプリ│ ◄────────────────► │  Flask Web   │ ◄───────────────► │  メール   │
│  (iOS/Android)│   HTTP :5858      │  (web_ui.py) │                   │  サーバー  │
└──────────────┘                    └──────┬───────┘                   └──────────┘
                                           │
                                    ┌──────▼───────┐
                                    │   SQLite     │
                                    │  (暗号化付き)  │
                                    └──────────────┘
```

### Web UI と Flutterアプリの違い

| | Flask Web UI | Flutterアプリ |
|---|---|---|
| **対象** | ブラウザ | ネイティブアプリ |
| **主な用途** | 初期セットアップ・アカウント管理 | 日常のメール閲覧 |
| **機能** | アカウント追加・削除、同期 | 統合inbox、フォルダ閲覧、検索 |
| **関係** | REST APIサーバーそのもの | REST APIのクライアント |

Web UIを削除するとREST APIも消えるため、両方維持しています。

## 📁 プロジェクト構成

```
email-mcp/
├── src/email_mcp/          # Pythonバックエンド
│   ├── server.py           # MCPサーバー — AI向けツール
│   ├── web_ui.py           # Flask REST API + Web UI
│   ├── database.py         # SQLiteデータ層
│   ├── imap_client.py      # IMAP取得（UIDベース・バッチ処理）
│   ├── smtp_client.py      # SMTP送信
│   ├── sync.py             # 同期管理（削除反映付き）
│   ├── crypto.py           # AES-256-GCM暗号化
│   └── config.py           # 設定
├── app/                    # Flutter管理アプリ
│   └── lib/
│       ├── models/         # データモデル
│       ├── screens/        # UI画面
│       └── services/       # APIクライアント
├── Dockerfile
├── docker-compose.yml
├── pyproject.toml
├── LICENSE
└── README.md
```

## 🔒 セキュリティ

- メールパスワードは **AES-256-GCM** で暗号化してSQLiteに保存
- 暗号化キーは `data/.encryption_key` に保存（gitignore済み、コミット対象外）
- AIクライアントはMCPツール経由でのみメールにアクセス — **生の認証情報は見えない**
- すべてのデータはローカルに留まる。クラウド送信なし、テレメトリなし

## ⚙️ 環境変数

| 変数 | デフォルト | 説明 |
|---|---|---|
| `EMAIL_MCP_WEB_HOST` | `0.0.0.0` | Web UIのバインドアドレス |
| `EMAIL_MCP_WEB_PORT` | `5858` | Web UIのポート番号 |

## 📄 ライセンス

[MIT](LICENSE) — © 2026 sashimi3433

## 🤝 コントリビュート

[CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。バグ報告・機能要望は [Issues](https://github.com/sashimi3433/email-mcp/issues) まで。
