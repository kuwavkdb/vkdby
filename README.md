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

## 注意事項
- サーバー起動後は `http://127.0.0.1:3000` でアクセス可能です。
- `bin/rails` 等を直接叩くとシステム Ruby が呼ばれてエラーになる可能性があるため、上記のように明示的にパスを通した実行を強く推奨します。
- PostgreSQL 17 を使用しています。データベース接続の設定は `config/database.yml` を参照してください。
