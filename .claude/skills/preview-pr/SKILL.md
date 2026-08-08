---
name: preview-pr
description: 指定したブランチ（指定しない場合はカレントブランチ）をもとに、release/v0.yyyy.mmdd.preview ブランチを作成し、PRを作成する（マージ先はmain）
---

# Preview PR 作成

以下の手順を **そのまま実行** してください。確認や提案は不要です。

## 手順

1. ベースブランチを決定する
   - 引数でブランチが指定された場合はそれを使う
   - 指定がない場合はカレントブランチ（`git branch --show-current`）を使う

2. ベースブランチに切り替えて最新化する
   ```
   git checkout <base_branch>
   git pull origin <base_branch>
   ```

3. バージョン番号を確定する（`release-pr` の通常リリースタグと重複しないようにする）
   - preview のブランチ名は、通常リリースと同じバージョン形式 `v0.YYYY.MMDD[.N]` の末尾に `.preview` を付けた形にする（例: `release/v0.2026.0227.preview`）。これにより、preview のまま `.preview` を外せばそのまま通常リリースのブランチ名として使える。
   - 今日の日付を取得する: `date +%Y.%m%d`（例: `2026.0227`）
   - タグと preview ブランチの両方から、今日の日付を使っているバージョンを集める（重複判定はこの両方を見る必要がある。通常リリースの `release-pr` はタグしか見ていないが、preview が先に同じ日付のバージョンを使っている場合もあるため）:
     ```
     git fetch origin --tags --quiet
     git tag --list "v0.<date>*"
     git ls-remote --heads origin "release/v0.<date>*.preview"
     ```
   - 上記2つの結果を合わせて、末尾のサフィックス番号を確認する
     - サフィックスなし（`v0.<date>` または `release/v0.<date>.preview`）は 1 として扱う
     - 見つかった中の最大値+1 を新しいサフィックスとする
   - 該当するタグ・ブランチが1件もない場合: `v0.<date>` をそのまま使う（サフィックスなし）
   - 該当する場合: 最大サフィックス+1 を付ける（例: `v0.2026.0227` が既に使われていれば `v0.2026.0227.2`）
   - 確定したバージョンを `<version>` とする（例: `v0.2026.0227` または `v0.2026.0227.2`）

4. プレビューブランチを作成する
   ```
   git checkout -b release/<version>.preview
   ```

5. リモートにpushする
   ```
   git push origin release/<version>.preview
   ```

6. PRを作成する（ベースブランチは `main`、タイトルに `[render preview]` を含める）
   ```
   gh pr create --base main --title "[render preview] release/<version>.preview" --body "## Preview release/<version>.preview\n\nベースブランチ: <base_branch>"
   ```

7. 作成したPRのURLをユーザーに表示する
