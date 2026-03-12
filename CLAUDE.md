# CLAUDE.md

## ブランチ運用
- 修正・機能開発のベースブランチは原則として `develop`
- ブランチ名は `feat/issue-{番号}-{内容}` の形式にする（例: `feat/issue-282-backslash-in-activity-period`）
- `/release-pr` スキルはリリース専用。機能修正・バグ修正には使わない
- `develop` および `main` への直接 push は禁止。必ずブランチを切って PR を作成すること

## コマンド実行
- Rails コマンドは必ず `bundle exec` をつける（例: `bundle exec rails db:migrate`）

## アクセシビリティ
- WEB アクセシビリティに考慮してデザインする
- コントラスト比を確保し、テキストが読みやすい色を選ぶ（WCAG AA 基準を目安にする）
- インタラクティブ要素（ボタン・リンク）はフォーカス状態を明示する
- 画像には適切な `alt` テキストを設定する
- アイコンのみのボタンには `sr-only` テキストや `aria-label` を付与する
