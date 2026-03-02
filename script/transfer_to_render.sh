#!/bin/sh
# ローカルの開発DBデータをRenderの本番DBに転送するスクリプト
# 事前に .envrc の DB_CONNECTION が設定されていること（direnv 等で読み込む）

set -e

if [ -z "$DB_CONNECTION" ]; then
  echo "エラー: DB_CONNECTION が設定されていません"
  echo "  .envrc に export DB_CONNECTION=... を設定し、direnv allow を実行してください"
  exit 1
fi

TABLES="units unit_people people trends items sections links index_groups tag_index_items tag_indices snapshot_people unit_snapshots users"
DB_NAME="vkdby_development"

TRUNCATE_SQL="TRUNCATE ${TABLES// /, } RESTART IDENTITY CASCADE;"

PG_DUMP_OPTS=""
for t in $TABLES; do
  PG_DUMP_OPTS="$PG_DUMP_OPTS -t $t"
done

echo "=== Renderへのデータ転送を開始します ==="
echo "転送対象テーブル: $TABLES"
echo ""
echo "警告: Renderの本番DBのデータが上書きされます。続行しますか？ [y/N]"
read -r answer
if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
  echo "中止しました"
  exit 0
fi

echo "--- データ転送中 ---"
(echo "$TRUNCATE_SQL" && pg_dump $PG_DUMP_OPTS -a "$DB_NAME") | psql "$DB_CONNECTION"

echo ""
echo "=== 転送完了 ==="
