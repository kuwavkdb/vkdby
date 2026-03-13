---
name: release-pr
description: developブランチから release/0.yyyy.mmdd ブランチを切ってpushし、PRを作成する
---

# Release PR 作成

以下の手順を **そのまま実行** してください。確認や提案は不要です。

## 手順

1. 今日の日付を取得して、ブランチ名を決定する
   - フォーマット: `release/0.YYYY.MMDD`（例: `release/0.2026.0227`）
   - Bash で `date +%Y.%m%d` を実行して取得する

2. `develop` ブランチに切り替えて最新化する
   ```
   git checkout develop
   git pull origin develop
   ```

3. リリースブランチを作成する
   ```
   git checkout -b release/0.<date>
   ```

4. リモートにpushする
   ```
   git push origin release/0.<date>
   ```

5. PRを作成する（ベースブランチは `main`）
   ```
   gh pr create --base main --title "release/0.<date>" --body "## Release 0.<date>"
   ```

6. 作成したPRのURLをユーザーに表示する
