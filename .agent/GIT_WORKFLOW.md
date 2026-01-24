# Git ワークフロー

## 基本原則

**⚠️ 重要: mainブランチへの直接pushは禁止**

すべての変更は以下のワークフローに従って行うこと。

---

## 標準ワークフロー

### 1. フィーチャーブランチの作成

新しい機能やバグ修正を始める前に、必ずフィーチャーブランチを作成する。

```bash
# mainブランチから最新の状態を取得
git checkout main
git pull origin main

# フィーチャーブランチを作成
git checkout -b feat/feature-name
# または
git checkout -b fix/bug-name
```

**ブランチ命名規則:**
- 新機能: `feat/機能名`
- バグ修正: `fix/バグ名`
- リファクタリング: `refactor/対象名`
- ドキュメント: `docs/内容`

### 2. 作業とコミット

```bash
# 変更を確認
git status
git diff

# ステージング
git add <ファイル名>
# または全ての変更
git add -A

# コミット
git commit -m "type: 変更内容の説明"
```

**コミットメッセージの形式:**
```
type: 簡潔な説明

詳細な説明（必要に応じて）
```

**type の種類:**
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメントのみの変更
- `style`: コードの意味に影響しない変更（空白、フォーマットなど）
- `refactor`: バグ修正や機能追加ではないコードの変更
- `test`: テストの追加や修正
- `chore`: ビルドプロセスやツールの変更

### 3. リモートへのpush

```bash
# フィーチャーブランチをリモートにpush
git push origin feat/feature-name
```

### 4. プルリクエストの作成

```bash
# GitHub CLIを使用する場合
gh pr create --title "feat: 機能名" --body "変更内容の詳細"

# または、GitHubのWebインターフェースから作成
```

### 5. レビューとマージ

1. CIが成功することを確認
2. 必要に応じてレビューを依頼
3. 承認後、GitHubでマージ
4. ローカルのmainブランチを更新

```bash
git checkout main
git pull origin main
git branch -d feat/feature-name  # マージ済みブランチを削除
```

---

## 緊急時の対応

### mainに誤ってpushしてしまった場合

#### オプション1: revertコミットを作成（推奨）

```bash
# 最新のコミットをrevert
git revert HEAD

# revertをpush
git push origin main
```

#### オプション2: force pushで取り消す（注意が必要）

```bash
# 1つ前のコミットに戻す
git reset --hard HEAD~1

# force push（他の人が既にpullしている場合は避ける）
git push origin main --force
```

---

## チェックリスト

作業を始める前に以下を確認:

- [ ] mainブランチから最新の状態をpullした
- [ ] フィーチャーブランチを作成した
- [ ] ブランチ名が命名規則に従っている

コミット前に以下を確認:

- [ ] 変更内容をレビューした（`git diff`）
- [ ] 不要なファイルが含まれていない
- [ ] コミットメッセージが適切

push前に以下を確認:

- [ ] **現在のブランチがmainではない**ことを確認（`git branch`）
- [ ] ローカルでテストが通る
- [ ] RuboCopエラーがない（`bin/rubocop`）

---

## よくある間違いと対策

### ❌ 間違い: mainブランチで直接作業

```bash
# 現在のブランチを確認せずに作業
git add .
git commit -m "fix: something"
git push origin main  # ❌ NG!
```

### ✅ 正しい方法

```bash
# 必ず現在のブランチを確認
git branch
# または
git status

# mainの場合は、フィーチャーブランチを作成
git checkout -b fix/something

# 作業後
git add .
git commit -m "fix: something"
git push origin fix/something  # ✅ OK!
```

---

## 便利なエイリアス設定

`.gitconfig`に以下を追加すると便利:

```ini
[alias]
  # 現在のブランチ名を表示
  current = rev-parse --abbrev-ref HEAD
  
  # mainブランチへのpushを防ぐ
  pushm = "!f() { \
    if [ $(git rev-parse --abbrev-ref HEAD) = 'main' ]; then \
      echo 'Error: Direct push to main is not allowed!'; \
      exit 1; \
    else \
      git push \"$@\"; \
    fi \
  }; f"
```

使用例:
```bash
# 安全なpush（mainの場合はエラーになる）
git pushm origin HEAD
```

---

## 参考リンク

- [GitHub Flow](https://docs.github.com/ja/get-started/quickstart/github-flow)
- [Conventional Commits](https://www.conventionalcommits.org/ja/)
