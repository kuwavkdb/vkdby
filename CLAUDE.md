# CLAUDE.md

## ブランチ運用
- 修正・機能開発のベースブランチは原則として `develop`
- ブランチ名は `feat/issue-{番号}-{内容}` の形式にする（例: `feat/issue-282-backslash-in-activity-period`）
- `/release-pr` スキルはリリース専用。機能修正・バグ修正には使わない

## コマンド実行
- Rails コマンドは必ず `bundle exec` をつける（例: `bundle exec rails db:migrate`）
