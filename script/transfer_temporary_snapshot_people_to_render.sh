#!/bin/sh
# temporary_snapshot_people テーブルのみをRenderの本番DBに転送するスクリプト
# 事前に .envrc の DB_CONNECTION が設定されていること（direnv 等で読み込む）
# 事前にRender側で temporary_snapshot_people テーブルのマイグレーションが
# 適用済みであること（通常はデプロイ時の `rails db:migrate` で自動適用される）

set -e

if [ -z "$DB_CONNECTION" ]; then
  echo "エラー: DB_CONNECTION が設定されていません"
  echo "  .envrc に export DB_CONNECTION=... を設定し、direnv allow を実行してください"
  exit 1
fi

TABLE="temporary_snapshot_people"
DB_NAME="vkdby_development"

echo "=== ${TABLE} テーブルのみをRenderへ転送します ==="
echo "警告: Renderの本番DBの ${TABLE} テーブルのデータが上書きされます。続行しますか？ [y/N]"
read -r answer
if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
  echo "中止しました"
  exit 0
fi

echo "--- データ転送中 ---"
(echo "TRUNCATE ${TABLE} RESTART IDENTITY CASCADE;" && pg_dump -t "$TABLE" -a "$DB_NAME") | psql "$DB_CONNECTION"

echo ""
echo "=== 転送完了 ==="
