# 実行・運用ガイド

本プロジェクトは Homebrew でインストールされた Ruby 4.0.0 に依存しています。システム標準の Ruby（2.6.x）との競合を避けるため、サーバーの起動や Rails 関連のコマンドを実行する際は、必ず `PATH` を指定し、`bundle exec` を使用してください。

## コマンド実行時の基本形式

以下のコマンド例のように、常に `PATH=/opt/homebrew/opt/ruby/bin:$PATH` を冠して実行してください。

```bash
# サーバーの起動
PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails server

# Gem のインストール
PATH=/opt/homebrew/opt/ruby/bin:$PATH bundle install

# マイグレーションの実行
PATH=/opt/homebrew/opt/ruby/bin:$PATH bundle exec rails db:migrate

# マイグレーションファイルの生成
PATH=/opt/homebrew/opt/ruby/bin:$PATH bundle exec rails generate migration NameOfMigration

# Rails コンソール
PATH=/opt/homebrew/opt/ruby/bin:$PATH bundle exec rails console

# Annotate（モデル定義のコメント更新）
PATH=/opt/homebrew/opt/ruby/bin:$PATH bundle exec annotate --models
```

## 注意事項
- サーバー起動後は `http://127.0.0.1:3000` でアクセス可能です。
- `bin/rails` 等を直接叩くとシステム Ruby が呼ばれてエラーになる可能性があるため、上記のように明示的にパスを通した実行を強く推奨します。
