#!/bin/bash
# ローカルの開発DBで取り込んだ Venue（import:venues）と、その Link を Render の本番DBに追加するスクリプト（issue #1688, #1690）
# 本番DBには wikipages がないため、会場の取り込みはローカルで行い、結果だけを本番に移す。
# 事前に .envrc の DB_CONNECTION が設定されていること（direnv 等で読み込む）
#
# - 本番の venues と Venue の links が空であることを確認してから追加する（既存データの上書き・削除はしない）
# - venues は ID をそのまま移す（links.linkable_id の参照先を保つため）。links は本番の ID と衝突するため振り直す
# - 1トランザクションで実行し、途中で失敗したら何も反映しない

set -euo pipefail

if [ -z "${DB_CONNECTION:-}" ]; then
  echo "エラー: DB_CONNECTION が設定されていません"
  echo "  .envrc に export DB_CONNECTION=... を設定し、direnv allow を実行してください"
  exit 1
fi

LOCAL_DB="${LOCAL_DB:-vkdby_development}"
LINK_COLUMNS="text, url, linkable_type, linkable_id, sort_order, active, created_at, updated_at"

venue_columns() {
  psql "$1" -At -c "SELECT string_agg(quote_ident(column_name), ', ' ORDER BY column_name)
                    FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'venues'"
}

remote_count() {
  psql "$DB_CONNECTION" -At -c "$1"
}

echo "=== 本番への Venue 転送 ==="
echo "転送元: $LOCAL_DB"
echo "  venues: $(psql "$LOCAL_DB" -At -c 'SELECT count(*) FROM venues') 件"
echo "  links（Venue）: $(psql "$LOCAL_DB" -At -c "SELECT count(*) FROM links WHERE linkable_type = 'Venue'") 件"

LOCAL_COLUMNS="$(venue_columns "$LOCAL_DB")"
if [ "$LOCAL_COLUMNS" != "$(venue_columns "$DB_CONNECTION")" ]; then
  echo "エラー: ローカルと本番で venues のカラムが一致しません（マイグレーションの状態を確認してください）"
  exit 1
fi

REMOTE_VENUES="$(remote_count 'SELECT count(*) FROM venues')"
REMOTE_LINKS="$(remote_count "SELECT count(*) FROM links WHERE linkable_type = 'Venue'")"
echo "転送先（本番）の現在の件数: venues ${REMOTE_VENUES} 件 / links（Venue） ${REMOTE_LINKS} 件"
if [ "$REMOTE_VENUES" != "0" ] || [ "$REMOTE_LINKS" != "0" ]; then
  echo "エラー: 本番に Venue またはその Link がすでにあるため中止します（ID・キーの衝突を避けるため）"
  exit 1
fi

echo ""
echo "本番DBに上記の venues と links を追加します。続行しますか？ [y/N]"
read -r answer
if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
  echo "中止しました"
  exit 0
fi

echo "--- 転送中 ---"
{
  echo "BEGIN;"
  echo "COPY venues (${LOCAL_COLUMNS}) FROM STDIN;"
  psql "$LOCAL_DB" -c "COPY (SELECT ${LOCAL_COLUMNS} FROM venues ORDER BY id) TO STDOUT"
  echo '\.'
  echo "COPY links (${LINK_COLUMNS}) FROM STDIN;"
  psql "$LOCAL_DB" -c "COPY (SELECT ${LINK_COLUMNS} FROM links WHERE linkable_type = 'Venue' ORDER BY id) TO STDOUT"
  echo '\.'
  # IDを指定して入れたため、以降に管理画面で作る Venue のIDが衝突しないよう連番を進めておく
  echo "SELECT setval(pg_get_serial_sequence('venues', 'id'), (SELECT max(id) FROM venues));"
  echo "COMMIT;"
} | psql "$DB_CONNECTION" -v ON_ERROR_STOP=1 -q

echo ""
echo "=== 転送完了 ==="
echo "本番の件数: venues $(remote_count 'SELECT count(*) FROM venues') 件 /" \
     "links（Venue） $(remote_count "SELECT count(*) FROM links WHERE linkable_type = 'Venue'") 件"
