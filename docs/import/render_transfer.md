# Renderへのデータ転送

ローカルの開発DBデータをRenderの本番DBに転送する手順です。

## 事前準備（初回のみ）

### 1. direnv のインストール

```bash
brew install direnv
```

`~/.zshrc` に hook を追加します。

```bash
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
source ~/.zshrc
```

### 2. .envrc の設定

リポジトリルートに `.envrc` を作成し、Renderの接続URLを設定します（`.envrc` はリポジトリに含まれません）。

```sh
export DB_CONNECTION=postgresql://<user>:<password>@<host>/<dbname>
```

接続URLはRenderのダッシュボード（Database > Connection String）から確認できます。

### 3. direnv に .envrc を許可する

```bash
direnv allow .
```

## データ転送

```bash
./script/transfer_to_render.sh
```

実行すると確認プロンプトが表示されます。`y` を入力すると転送が開始されます。

転送対象テーブル: `units`, `unit_people`, `people`, `trends`, `items`, `sections`, `links`, `index_groups`, `tag_index_items`, `tag_indices`, `snapshot_people`, `unit_snapshots`, `users`

## 特定テーブルのみの転送

新規追加したテーブルなど、特定の1テーブルだけをRenderに転送したい場合は個別スクリプトを用意する。

- `temporary_snapshot_people` テーブルのみを転送する場合:

  ```bash
  ./script/transfer_temporary_snapshot_people_to_render.sh
  ```

  Render側で対象テーブルのマイグレーションが適用済み（デプロイ済み）であることが前提。
