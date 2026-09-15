---
name: merge-pr
description: mainブランチの最新タグを元に、feat/merge-{release_tag} ブランチを切ってdevelopへのPRを作成する
---

# Merge PR 作成

以下の手順を **そのまま実行** してください。確認や提案は不要です。

## 手順

1. origin から最新情報を取得し、最新の release タグを取得する
   ```
   git fetch origin --tags
   git tag --sort=-creatordate | head -1
   ```
   - タグは `v0.YYYY.MMDD` 形式（例: `v0.2026.0303`）
   - ブランチ名用に先頭の `v` を除いた文字列を使う（例: `0.2026.0303`）

2. `main` ブランチを最新化する
   ```
   git checkout main
   git pull origin main
   ```

3. `feat/merge-{release_tag}` ブランチを作成する（main ベース）
   ```
   git checkout -b feat/merge-<release_tag>
   ```

4. リモートに push する
   ```
   git push origin feat/merge-<release_tag>
   ```

5. PR を作成する（ベースブランチは `develop`）
   ```
   gh pr create --base develop --title "feat/merge-<release_tag>" --body "## Merge release <release_tag> into develop"
   ```

6. 作成した PR の URL をユーザーに表示する

7. **重要: このPRをマージする際は、必ず「Create a merge commit」（マージコミット）を選択すること**
   - `gh pr merge <PR番号> --merge` を使うか、GitHub UI 上で "Squash and merge" ではなく "Merge pull request" を選ぶ
   - このPRは main の内容を develop に取り込むためだけのPRであり、squash マージすると main 上のコミットとは別ハッシュのコミットが develop にできてしまい、main と develop の共通祖先が更新されない
   - 共通祖先が更新されないと、次回以降 `release-pr` で作成するPRの diff・コミット一覧に、過去にリリース済みの変更が毎回再表示されてしまう（このリポジトリで実際に発生した問題）
