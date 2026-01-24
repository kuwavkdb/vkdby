#!/bin/bash
# MySQLダンプファイルからPostgreSQLにwikipagesデータをインポートするスクリプト

set -e

# PostgreSQL 17のパスを設定
PSQL="/opt/homebrew/opt/postgresql@17/bin/psql"

echo "=== MySQLダンプからPostgreSQLへのデータ移行 ==="

# 1. MySQLダンプからwikipagesテーブルのINSERT文を抽出
echo "--- MySQLダンプファイルを処理中 ---"
grep "^INSERT INTO \`wikipages\`" wikipages_all_20260114.sql > /tmp/wikipages_inserts.sql || {
  echo "✗ wikipages_all_20260114.sqlファイルが見つかりません"
  exit 1
}

# 2. MySQL形式のINSERT文をPostgreSQL形式に変換
echo "--- PostgreSQL形式に変換中 ---"
sed -i '' "s/\`wikipages\`/wikipages/g" /tmp/wikipages_inserts.sql
sed -i '' "s/\\\\\\\\/\\\\/g" /tmp/wikipages_inserts.sql  # エスケープ文字の調整

# 3. PostgreSQLにインポート
echo "--- PostgreSQLにインポート中 ---"
$PSQL -U $USER -d vkdby_development -f /tmp/wikipages_inserts.sql

# 4. シーケンスをリセット
echo "--- シーケンスをリセット中 ---"
$PSQL -U $USER -d vkdby_development -c "SELECT setval('wikipages_id_seq', (SELECT MAX(id) FROM wikipages));"

# 5. データ確認
echo "--- データ確認 ---"
COUNT=$($PSQL -U $USER -d vkdby_development -t -c "SELECT COUNT(*) FROM wikipages;")
echo "✓ インポート完了: $COUNT レコード"

echo "=== 移行完了 ==="
