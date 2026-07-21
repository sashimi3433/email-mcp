# 📱 Flutter アプリ

Email MCPのネイティブクライアントアプリ。iOS・Android・macOS対応。

REST API（`web_ui.py`）に接続して、メールの閲覧・検索・アカウント管理を行います。

## ✨ 機能

### 📧 メール閲覧
- **統合inbox** — 全アカウントのINBOXを1つのタイムラインに統合
- **アカウント別表示** — 個別アカウントのフォルダ（INBOX / Sent / Trash等）を切り替え表示
- **メッセージ詳細** — ヘッダー情報（From / To / Cc / 日付）+ 本文表示
- **プル・ツー・リフレッシュ** — 画面を下に引っ張って最新情報に更新

### 🔍 検索
- 件名・差出人・本文からの全文検索
- アカウント指定または全アカウント横断

### ⚙️ アカウント管理
- アカウントの追加・編集・削除
- ドメイン設定の登録（`@example.com` → IMAP/SMTP設定を自動入力）
- ワンタップ同期

### 🎨 UI
- Material 3 デザイン
- Noto Sans JP による日本語フォント指定（中華フォント回避）
- ダークモード対応

## 🚀 ビルド手順

### 前提条件

- Flutter 3.x
- Android SDK（Androidビルドの場合）
- Xcode（iOS/macOSビルドの場合、macOS環境が必要）

### セットアップ

```bash
cd app
flutter pub get
```

### 実行

```bash
# 接続されているデバイスで実行
flutter run

# リリースビルド（APK）
flutter build apk --release --split-per-abi

# リリースビルド（macOS）
flutter build macos --release
```

### ビルド環境変数（Android）

```bash
export ANDROID_HOME=/path/to/android-sdk
export JAVA_HOME=/path/to/jdk-21
export PATH="$JAVA_HOME/bin:$PATH"
```

## 📱 画面構成

ナビゲーションは4タブ構成:

### 1. メール（ホーム）
- 「すべてのメール」カード → 統合inboxへ
- 登録アカウント一覧
- アカウントをタップ → 個別フォルダ表示
- 右下「+」ボタン → アカウント追加

### 2. ドメイン
- サーバードメイン設定の一覧・追加・削除
- ドメイン追加でアカウント追加時の入力を省略可能

### 3. 検索
- アカウント選択 + キーワード入力で全文検索
- 検索結果タップ → メッセージ詳細

### 4. 設定
- サーバーアドレス変更（デフォルト: `http://localhost:5858`）
- 接続状態表示

## 🔗 サーバー接続

アプリはデフォルトで `http://localhost:5858` に接続します。

### リモート接続
スマホから自宅サーバーにアクセスする場合:
1. **同じネットワーク**: サーバーのIPアドレスを指定（例: `http://192.168.1.100:5858`）
2. **VPN経由**: Headscale/Tailscale等のVPNで接続後、VPN IPを指定（例: `http://100.64.0.4:5858`）

設定タブでサーバーアドレスを変更できます。

## 📁 ソース構成

```
app/lib/
├── main.dart                    # エントリポイント・テーマ設定
├── models/
│   ├── account.dart             # アカウントモデル
│   ├── email_message.dart       # メッセージモデル
│   └── server_domain.dart       # ドメイン設定モデル
├── services/
│   └── api_service.dart         # REST APIクライアント（Dio使用）
├── screens/
│   ├── home_screen.dart         # ホーム（メール + アカウント一覧）
│   ├── unified_inbox_screen.dart # 統合inbox
│   ├── messages_screen.dart     # アカウント別メッセージ一覧
│   ├── message_detail_screen.dart # メッセージ詳細
│   ├── search_screen.dart       # 検索画面
│   ├── domains_screen.dart      # ドメイン管理
│   ├── domain_form_screen.dart  # ドメイン追加・編集フォーム
│   ├── account_form_screen.dart # アカウント追加・編集フォーム
│   └── settings_screen.dart     # 設定画面
└── widgets/
    └── empty_state.dart         # 空状態ウィジェット
```
