#!/usr/bin/env bash
# 本番DBバックアップ（.github/workflows/backup.yml）を手動実行し、
# 完了を待って Artifact（pg_dump ファイル）をダウンロードする。
#
# 使い方:
#   bin/backup-db.sh [ダウンロード先ディレクトリ（省略時: tmp/backup）]
#
# 前提: gh CLI がインストール済みで、対象リポジトリへのアクセス権があること。
#       (参考: https://cli.github.com/)

set -o errexit
set -o pipefail
set -o nounset

REPO="kuwavkdb/vkdby"
WORKFLOW="backup.yml"
DEST_DIR="${1:-tmp/backup}"

echo "==> ワークフローを手動実行します（${WORKFLOW}）"
BEFORE=$(date -u +%s)
gh workflow run "$WORKFLOW" --repo "$REPO"

echo "==> 実行された run を検出しています..."
RUN_ID=""
for _ in $(seq 1 30); do
  RUN_ID=$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit 5 \
    --json databaseId,createdAt \
    --jq "[.[] | select((.createdAt | fromdateiso8601) >= ${BEFORE} - 5)] | sort_by(.createdAt) | last | .databaseId // empty")
  if [ -n "$RUN_ID" ]; then
    break
  fi
  sleep 2
done

if [ -z "$RUN_ID" ]; then
  echo "エラー: 実行された run を検出できませんでした（時間をおいて 'gh run list --repo ${REPO} --workflow ${WORKFLOW}' で確認してください）" >&2
  exit 1
fi

echo "==> run #${RUN_ID} の完了を待機します"
gh run watch "$RUN_ID" --repo "$REPO" --exit-status

echo "==> Artifact をダウンロードします → ${DEST_DIR}"
mkdir -p "$DEST_DIR"
gh run download "$RUN_ID" --repo "$REPO" --dir "$DEST_DIR"

echo "==> 完了しました:"
find "$DEST_DIR" -type f
