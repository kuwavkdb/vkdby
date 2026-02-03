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

## 注意事項
- サーバー起動後は `http://127.0.0.1:3000` でアクセス可能です。
- `bin/rails` 等を直接叩くとシステム Ruby が呼ばれてエラーになる可能性があるため、上記のように明示的にパスを通した実行を強く推奨します。
- PostgreSQL 17 を使用しています。データベース接続の設定は `config/database.yml` を参照してください。
