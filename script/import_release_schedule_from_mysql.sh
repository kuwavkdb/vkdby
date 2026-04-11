# MySQLダンプファイルからPostgreSQLにrelease_schedulesデータをインポートするスクリプト

set -e

# PostgreSQL 17のパスを設定
PSQL="/opt/homebrew/opt/postgresql@17/bin/psql"
DB_NAME="vkdby_development"
SRC_SQL="./vkdb_dump/release_schedule_all_20260411.sql"
TMP_SQL="/tmp/release_schedule_inserts.sql"

echo "=== MySQLダンプからPostgreSQLへのデータ移行 (release_schedule) ==="

# 1. MySQLダンプを処理用一時ファイルにコピー（フィルタリングして抽出）
echo "--- MySQLダンプファイルを処理中 (全行スキャン) ---"
if [ ! -f "$SRC_SQL" ]; then
  echo "✗ $SRC_SQL ファイルが見つかりません"
  exit 1
fi

# Prepend configuration
echo "SET standard_conforming_strings = off;" > "$TMP_SQL"
echo "SET client_encoding = 'UTF8';" >> "$TMP_SQL"

# ダンプから INSERT 文とデータ行抽出
# 行頭が "INSERT INTO" または "(" で始まる行のみを抽出することで、
# マルチラインINSERTのデータ行も確保しつつ、CREATE TABLE等を排除する。
# mysqldumpの出力形式（行頭にスペースがない前提）に依存。
grep -E "^(INSERT INTO \`release_schedule\`|\()" "$SRC_SQL" >> "$TMP_SQL"

# 2. MySQL形式のINSERT文をPostgreSQL形式に変換
echo "--- PostgreSQL形式に変換中 ---"

# テーブル名を release_schedules に変更し、識別子のバッククォートをダブルクォートに変換
sed -i '' "s/\`release_schedule\`/\"release_schedules\"/g" "$TMP_SQL"
# カラム名のバッククォートをダブルクォートに変換 (簡易的な置換)
sed -i '' "s/\`id\`/\"id\"/g" "$TMP_SQL"
sed -i '' "s/\`artist\`/\"artist\"/g" "$TMP_SQL"
sed -i '' "s/\`wiki\`/\"wiki\"/g" "$TMP_SQL"
sed -i '' "s/\`title\`/\"title\"/g" "$TMP_SQL"
sed -i '' "s/\`release_date\`/\"release_date\"/g" "$TMP_SQL"
sed -i '' "s/\`created_at\`/\"created_at\"/g" "$TMP_SQL"
sed -i '' "s/\`type\`/\"type\"/g" "$TMP_SQL"
sed -i '' "s/\`plugin_text\`/\"plugin_text\"/g" "$TMP_SQL"
sed -i '' "s/\`plugin_full\`/\"plugin_full\"/g" "$TMP_SQL"
sed -i '' "s/\`append_before\`/\"append_before\"/g" "$TMP_SQL"
sed -i '' "s/\`append_after\`/\"append_after\"/g" "$TMP_SQL"
sed -i '' "s/\`publisher\`/\"publisher\"/g" "$TMP_SQL"
sed -i '' "s/\`product_group\`/\"product_group\"/g" "$TMP_SQL"
sed -i '' "s/\`img_url\`/\"img_url\"/g" "$TMP_SQL"
sed -i '' "s/\`l_img_url\`/\"l_img_url\"/g" "$TMP_SQL"
sed -i '' "s/\`url\`/\"url\"/g" "$TMP_SQL"
sed -i '' "s/\`tracks\`/\"tracks\"/g" "$TMP_SQL"
sed -i '' "s/\`updated_at\`/\"updated_at\"/g" "$TMP_SQL"
sed -i '' "s/\`asin\`/\"asin\"/g" "$TMP_SQL"
sed -i '' "s/\`tower_id\`/\"tower_id\"/g" "$TMP_SQL"

# 0000-00-00 の日付を NULL に変換 (VALUES (...) 内のものでもマッチするように)
# 文字列としての '0000-00-00' を NULL に置換
sed -i '' "s/'0000-00-00 00:00:00'/NULL/g" "$TMP_SQL"
sed -i '' "s/'0000-00-00'/NULL/g" "$TMP_SQL"

# エスケープ文字の調整 (必要に応じて)
# standard_conforming_strings = off なので \ はエスケープとして扱われる。
# MySQLの \' は PGでも \' となり、シングルクォートのエスケープとして機能するはず。

# 3. 既存データ削除 (TRUNCATE)
echo "--- 既存データを削除中 ---"
$PSQL -U $USER -d "$DB_NAME" -c "TRUNCATE TABLE release_schedules;"

# 4. PostgreSQLにインポート
echo "--- PostgreSQLにインポート中 ---"
$PSQL -U $USER -d "$DB_NAME" -f "$TMP_SQL"

# 5. シーケンスをリセット
echo "--- シーケンスをリセット中 ---"
$PSQL -U $USER -d "$DB_NAME" -c "SELECT setval('release_schedules_id_seq', (SELECT MAX(id) FROM release_schedules));"

# 6. データ確認
echo "--- データ確認 ---"
COUNT=$($PSQL -U $USER -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM release_schedules;")
echo "✓ インポート完了: $COUNT レコード"

echo "=== 移行完了 ==="
