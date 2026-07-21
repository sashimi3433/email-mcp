# 🏗️ アーキテクチャ

## 全体構成

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

## コンポーネント

### 1. MCPサーバー (`server.py`)

AIクライアント（Claude Desktop等）とstdio通信するMCPサーバー。AIから使えるメールツールを提供します。

- **通信方式**: MCP (Model Context Protocol) over stdio
- **ツール数**: 7個（list_accounts, list_messages, get_message, search_messages, sync_account, send_reply, send_mail）
- **セキュリティ**: 認証情報はAIに非公開。ツール経由のデータのみ提供

### 2. Flask Web UI + REST API (`web_ui.py`)

2つの役割を持つサーバー:

- **Web UI**: ブラウザでアクセス可能なHTML管理画面（`/`）
- **REST API**: Flutterアプリ等からのプログラムマティックアクセス（`/api/*`）

これらは同一プロセス・同一ポート（5858）で動作します。

### 3. Flutterアプリ (`app/`)

REST APIを叩くネイティブクライアント。iOS・Android・macOS対応。

### 4. SQLiteデータベース (`data/emails.db`)

3つのテーブルで構成:

- **server_domains**: ドメイン別IMAP/SMTP設定
- **accounts**: メールアカウント（パスワードは暗号化）
- **messages**: キャッシュされたメール

### 5. IMAPクライアント (`imap_client.py`)

メール取得の中核。以下の特徴を持ちます:

- **UIDベース取得**: シーケンス番号ではなくUIDを使用（セッション間で安定）
- **バッチ処理**: 50件単位でFETCH（大容量フォルダのタイムアウト防止）
- **UTC正規化**: 全日付をUTCに統一してソート順を保証

### 6. 同期エンジン (`sync.py`)

各フォルダで3ステップの同期を実行:

1. **サーバーUID取得**: IMAPサーバーの現在のUID一覧を取得
2. **削除反映**: ローカルにあってサーバーにないUID = 削除済みメール → DBから削除
3. **新規・更新取得**: サーバーの現在のメールをupsert

これにより、他のクライアントで削除・移動されたメールが正しく反映されます。

## セキュリティモデル

```
ユーザー                    AIクライアント
  │                            │
  │ パスワード入力              │
  ▼                            │
Web UI ──► AES-256暗号化 ──► SQLite
              │                  │
              │     MCPツール    │
              │  ┌───────────────┤
              │  │               │
              ▼  ▼               │
         暗号化キー           ツール経由で
         (ファイル)         メールデータのみ提供
                              (パスワードは非公開)
```

## データフロー例

### メール同期の流れ

```
1. Flutter アプリが「同期」ボタンタップ
2. → POST /api/accounts/{id}/sync
3. → sync_account() が各フォルダで:
     a. IMAPサーバーからUID一覧取得
     b. 削除されたメッセージをDBから削除
     c. IMAPサーバーから全メッセージをFETCH (UID, FLAGS, RFC822)
     d. メッセージを解析してDBにupsert
4. ← {messages_synced, messages_deleted, folders_synced} を返却
5. Flutter アプリが一覧を再読込
```

### AIからのメール読み取り

```
1. AIが「最新メールを教えて」と要求
2. → MCPツール list_messages(account_id=2)
3. → SQLiteキャッシュから取得 (IMAP通信なし)
4. ← メール一覧を返却
5. AIが「このメールの詳細を見せて」と要求
6. → MCPツール get_message(account_id=2, message_id=123)
7. ← 本文を返却
```
