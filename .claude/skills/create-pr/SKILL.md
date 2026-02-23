---
name: create-pr
description: ブランチ作成・コミット・プッシュ・PR作成を一括で行う。issue 対応後に使用する。
disable-model-invocation: true
---

## 現在の状態
- Branch: !`git rev-parse --abbrev-ref HEAD`
- Status: !`git status --short`
- Recent commits: !`git log --oneline -3`

## 手順

ARGUMENTS にブランチ名・issue 番号・コミットメッセージのヒントが渡される場合はそれを使用する。

1. **ブランチ作成**
   - ベースブランチは `develop`（現在 develop にいない場合は確認する）
   - ブランチ名の命名規則: `feat/<内容>-<issue番号>` または `fix/<内容>-<issue番号>`
   - 例: `feat/import-items-artist-alias-295`

2. **ファイルをステージング**
   - 変更・追加されたファイルを `git add` で追加する
   - `.env` や機密情報を含むファイルは絶対に追加しない

3. **コミット**
   - メッセージは日本語で内容を端的に表す
   - 末尾に必ず Co-Authored-By を付ける:
     ```
     Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
     ```

4. **プッシュ**
   - `git push -u origin <ブランチ名>`
   - pre-push hook でテストと RuboCop が実行される。失敗した場合は修正してから再度コミット・プッシュする

5. **PR 作成**
   - ベースブランチ: `develop`
   - タイトル: コミットメッセージと同様に端的に
   - 本文テンプレート:
     ```
     ## Summary
     - <変更内容を箇条書きで>

     ## Test plan
     - [ ] `bin/rails test` が全件パスすること
     - [ ] <動作確認の観点>

     Closes #<issue番号>

     🤖 Generated with [Claude Code](https://claude.com/claude-code)
     ```
   - コマンド: `gh pr create --title "..." --body "..." --base develop`

6. **完了報告**
   - PR の URL をユーザーに伝える
