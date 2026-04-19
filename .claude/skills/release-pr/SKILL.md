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

3. main との差分コミットから issue 番号を収集する
   - 以下のコマンドで issue 番号を抽出する（`issue #NNN` 形式とブランチ名 `feat/issue-NNN-` 形式に対応）:
     ```
     git log origin/main..develop --oneline | grep -oE 'issue[ -]#?[0-9]+|feat/issue-[0-9]+' | grep -oE '[0-9]+' | sort -u
     ```
   - issue が1件も見つからない場合は「変更内容なし（依存関係更新のみ等）」と記載する

4. リリースブランチを作成する
   ```
   git checkout -b release/0.<date>
   ```

5. リモートにpushする
   ```
   git push origin release/0.<date>
   ```

6. PRを作成する（ベースブランチは `main`）
   収集した issue 一覧を PR の本文に含める。フォーマット:
   ```
   ## Release 0.<date>

   ### 含まれる変更

   - #123
   - #456
   ```

   ```
   gh pr create --base main --title "release/0.<date>" --body "<上記フォーマットの本文>"
   ```

7. 作成したPRのURLをユーザーに表示する
