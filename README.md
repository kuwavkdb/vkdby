# 実行・運用ガイド

本プロジェクトは Homebrew でインストールされた Ruby 4.0.0 と PostgreSQL 17 に依存しています。システム標準の Ruby（2.6.x）との競合を避けるため、サーバーの起動や Rails 関連のコマンドを実行する際は、必ず `PATH` を指定し、`bundle exec` を使用してください。

## 前提条件

### PostgreSQL 17 のインストール

```bash
# PostgreSQL 17をインストール
brew install postgresql@17

# PostgreSQLサービスを起動
brew services start postgresql@17
```

## コマンド実行時の基本形式

まず .zshrc 等に以下のようにPATHを追加してから実行してください。
```
PATH=/opt/homebrew/opt/ruby/bin:$PATH 
```

```bash
# サーバーの起動
bin/rails server

# Gem のインストール
bundle install

# データベースのセットアップ
bin/rails db:create db:migrate

# マイグレーションの実行
bundle exec rails db:migrate

# マイグレーションファイルの生成
bundle exec rails generate migration NameOfMigration

# Rails コンソール
bundle exec rails console

# RuboCop
bundle exec rubocop

# Annotate（モデル定義のコメント更新）
bundle exec annotaterb models

# テストの実行
bin/rails test
```

## バックアップ

### 自動バックアップ

本番環境（Render.com）のデータベースバックアップは2段階で管理しています。

| 種類 | 保持期間 | 仕組み |
|------|----------|--------|
| Render.com 自動バックアップ | 7日間 | Render Basic プランに付属 |
| GitHub Actions バックアップ | 180日間 | 週次（毎週月曜 JST 05:00）で `pg_dump` を実行し Artifact として保存 |

### 手動実行

GitHub Actions の **Database Backup** ワークフローを `workflow_dispatch` で手動実行できます。

```bash
gh workflow run backup.yml --repo kuwavkdb/vkdby
```

手動実行から Artifact のダウンロードまでを一括で行う場合は `bin/backup-db.sh` を使用してください（`gh` CLI が必要です）。

```bash
# tmp/backup/ にダウンロードされる
bin/backup-db.sh

# ダウンロード先を指定する場合
bin/backup-db.sh /path/to/dir
```

### バックアップからの復元

1. GitHub → Actions → Database Backup → 対象の実行 → Artifacts からダンプファイルをダウンロード
2. ローカルに復元:

```bash
pg_restore --no-owner --no-acl -d <接続先DB> vkdby_YYYYMMDD_HHMMSS.dump
```

## 「今日は何の日？」投稿文

X に投稿する「今日は何の日？」の紹介文を、GitHub Actions の **On This Day** ワークフロー（`.github/workflows/on_this_day.yml`）が毎日 JST 20:05 に翌日分を作り、GitHub の Issue にコメントします（GitHub のスケジュール実行は数時間遅れることがあるため、前日の夜に実行する）。

投稿文は「出来事」と「誕生日」の2件に分かれ、それぞれ X の上限280文字に入るだけ載せます（入りきらなければ「・他」）。

- 出来事: 解散・活動休止・メジャーデビュー・結成・初ライブ・活動再開を優先し、その中でメジャー経験バンドを先にする。1バンド1件まで
- 誕生日: 1人1行で、人物の経歴に最後に書かれたユニット名を括弧書きで付ける。経歴がその後「→」で終わっていれば `（ex-ユニット名）`、経歴が空なら名前だけ

### 見方

1. GitHub の Issues で、ラベル `on-this-day` の付いた Issue を開く（初回の実行で自動作成される）
2. その日のコメントにある投稿文をコピーするか、「X の投稿画面を開く（投稿文入力済み）」から投稿する
   - 載せる動向・誕生日がない日は「投稿文はありません」とコメントされる
   - 同じ内容は Actions の実行結果ページ（Job Summary）にも表示される

コメントが付くたびに通知を受け取るには、リポジトリを Watch するか、その Issue を Subscribe してください（モバイルアプリにも届きます）。Issue を close すると、次回の実行で新しい Issue が作られます。

### 手動実行

GitHub → Actions → On This Day → Run workflow から実行できます。`date` に `MM-DD` を入れるとその日の投稿文を、空なら JST の当日分をコメントします（何度実行してもその都度コメントされます）。

```bash
gh workflow run on_this_day.yml --repo kuwavkdb/vkdby -f date=05-30
```

Issue に書き込まずにローカルで投稿文だけ確認する場合:

```bash
bin/rails on_this_day:preview DATE=05-30
```

### 必要な設定

| 設定先 | 名前 | 内容 |
|--------|------|------|
| Render の環境変数 | `ON_THIS_DAY_MAIL_TOKEN` | 投稿文 API（`GET /internal/on_this_day_post`）の認証トークン。未設定なら API は 404 |
| GitHub の Secrets | `ON_THIS_DAY_MAIL_TOKEN` | 上と同じ値 |

## 注意事項
- サーバー起動後は `http://127.0.0.1:3000` でアクセス可能です。
- `bin/rails` 等を直接叩くとシステム Ruby が呼ばれてエラーになる可能性があるため、上記のように明示的にパスを通した実行を強く推奨します。
- PostgreSQL 17 を使用しています。データベース接続の設定は `config/database.yml` を参照してください。
