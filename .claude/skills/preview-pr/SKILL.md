---
name: preview-pr
description: 指定したブランチ（指定しない場合はカレントブランチ）をもとに、release/yyyy.mm.dd.preview ブランチを作成し、PRを作成する（マージ先はmain）
---

# Preview PR 作成

以下の手順を **そのまま実行** してください。確認や提案は不要です。

## 手順

1. ベースブランチを決定する
   - 引数でブランチが指定された場合はそれを使う
   - 指定がない場合はカレントブランチ（`git branch --show-current`）を使う

2. 今日の日付を取得して、ブランチ名を決定する
   - フォーマット: `release/YYYY.MM.DD.preview`（例: `release/2026.03.07.preview`）
   - Bash で `date +%Y.%m.%d` を実行して取得する

3. ベースブランチに切り替えて最新化する
   ```
   git checkout <base_branch>
   git pull origin <base_branch>
   ```

4. プレビューブランチを作成する
   ```
   git checkout -b release/<date>.preview
   ```

5. リモートにpushする
   ```
   git push origin release/<date>.preview
   ```

6. PRを作成する（ベースブランチは `main`、タイトルに `[render preview]` を含める）
   ```
   gh pr create --base main --title "[render preview] release/<date>.preview" --body "## Preview release/<date>.preview\n\nベースブランチ: <base_branch>"
   ```

7. 作成したPRのURLをユーザーに表示する
