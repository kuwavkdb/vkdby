---
name: merge-pr
description: mainにマージされたリリースPRのバージョンでタグ（GitHub Release）を発行し、feat/merge-{release_tag} ブランチを切ってdevelopへのPRを作成する
---

# Merge PR 作成

以下の手順を **そのまま実行** してください。確認や提案は不要です（手順の中で「中止」とある場合を除く）。

## 手順

1. `main` ブランチを最新化し、タグも取得する
   ```
   git fetch origin --tags
   git checkout main
   git pull origin main
   ```

2. main の先頭コミットから、発行するバージョンを決める
   ```
   git log -1 --format=%s main
   ```
   - リリースPRのマージコミットなら `Merge pull request #NNN from kuwavkdb/release/v1.YYYY.MMDD(.N)` の形になっている
   - `release/` の後ろ（例: `v1.2026.1004.2`）を `<version>` とする
   - 先頭の `v` を除いた文字列（例: `1.2026.1004.2`）を `<release_tag>` とする
   - **この形でなければ中止する**（リリースPRがまだマージされていない等）。ユーザーに main の先頭コミットを伝えて確認を求める

3. タグ（GitHub Release）を発行する
   - まず `<version>` のタグがすでにあるか確認する
     ```
     git tag -l <version>
     ```
   - **タグがない場合**: main の先頭コミットに GitHub Release を作成する（タグも同時に作られる）。リリースノートは自動生成する
     ```
     gh release create <version> --target "$(git rev-parse main)" --title "<version>" --generate-notes
     ```
     作成後、`git fetch origin --tags` でタグを取得しておく
   - **タグがあり、main の先頭コミットを指している場合**: 発行済みなので作成をスキップする
     ```
     git rev-list -n 1 <version>   # git rev-parse main と一致するか確認
     ```
   - **タグがあるが、別のコミットを指している場合**: 中止して、ユーザーに状況（タグが指すコミットと main の先頭コミット）を伝える

4. `feat/merge-<release_tag>` ブランチを作成する（main ベース）
   ```
   git checkout -b feat/merge-<release_tag>
   ```

5. リモートに push する
   ```
   git push origin feat/merge-<release_tag>
   ```

6. PR を作成する（ベースブランチは `develop`）
   ```
   gh pr create --base develop --title "feat/merge-<release_tag>" --body "## Merge release <release_tag> into develop"
   ```

7. 発行した GitHub Release の URL（`gh release view <version> --json url -q .url`）と、作成した PR の URL をユーザーに表示する

8. **重要: このPRをマージする際は、必ず「Create a merge commit」（マージコミット）を選択すること**
   - `gh pr merge <PR番号> --merge` を使うか、GitHub UI 上で "Squash and merge" ではなく "Merge pull request" を選ぶ
   - このPRは main の内容を develop に取り込むためだけのPRであり、squash マージすると main 上のコミットとは別ハッシュのコミットが develop にできてしまい、main と develop の共通祖先が更新されない
   - 共通祖先が更新されないと、次回以降 `release-pr` で作成するPRの diff・コミット一覧に、過去にリリース済みの変更が毎回再表示されてしまう（このリポジトリで実際に発生した問題）
