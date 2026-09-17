# メール送信のセットアップ（Gmail SMTP）

本番環境でのメール送信（ユニット/動向投稿のadmin通知、管理者アカウント発行時のパスワード通知）は Gmail の SMTP サーバー経由で行う。

## 背景

- ユニット/動向投稿フォームの admin 通知メール（`UserMailer#new_unit_submission_email` / `new_trend_submission_email`）、管理者アカウント発行時のパスワード通知（`UserMailer#welcome_email`）で使用
- 送信頻度は低く（投稿があった時のみ）、宛先も admin のみのため、専用のトランザクションメールサービス（SendGrid等）ではなく無料の Gmail SMTP を採用（[issue #1560](https://github.com/kuwavkdb/vkdby/issues/1560)）
- Render自体はSMTPサーバーを提供していないが、アウトバウンド通信（ポート587/STARTTLS）は許可されているため、外部SMTPサーバー経由での送信が可能

## セットアップ手順

### 1. 通知に使うGmailアカウントで2段階認証を有効化

1. 対象のGmailアカウントでログインした状態でGoogleアカウント設定を開く（Gmail右上のアイコン →「Google アカウントを管理」）
2. 左メニューの「セキュリティ」→「2 段階認証プロセス」を選択し、画面の指示に従って有効化する
   - Google Workspace（組織用）アカウントの場合、管理者がこの機能自体を制限していることがある

### 2. アプリパスワードを発行

2段階認証を有効にすると「セキュリティ」ページに「アプリ パスワード」の項目が表示される（2段階認証が無効だと表示されない）。

1. 「アプリ パスワード」を選択
2. わかりやすいアプリ名を入力（例: `vkdby production`）して作成
3. `xxxx xxxx xxxx xxxx` 形式（16文字）のパスワードが1回だけ表示されるのでコピーしておく（再表示不可、失敗したら再発行）

### 3. Rails credentials に登録

ローカルで実行する（本番デプロイ後ではなく、**デプロイ前にローカルで**行う）。

```bash
EDITOR="vim" bin/rails credentials:edit
# もしくは VISUAL="code --wait" bin/rails credentials:edit
```

既存の内容を残したまま、トップレベルに以下を追記して保存する。

```yaml
smtp:
  user_name: xxxxx@gmail.com
  password: xxxx-xxxx-xxxx-xxxx # 手順2で発行したアプリパスワード
```

保存すると `config/credentials.yml.enc`（暗号化済み・Gitコミット対象）が更新される。復号キーは `config/master.key`（gitignore対象、ローカルのみ）で、本番側は Render の環境変数 `RAILS_MASTER_KEY`（[render.yaml](../../render.yaml)、`sync: false`）に既に設定済みのため、本番側で別途の登録作業は不要。更新された `credentials.yml.enc` をコミット・pushしてデプロイすれば反映される。

## 関連ファイル

- [config/environments/production.rb](../../config/environments/production.rb) — `smtp_settings`（`smtp.gmail.com:587`, STARTTLS）、`default_url_options`
- [app/mailers/application_mailer.rb](../../app/mailers/application_mailer.rb) — `from` を `smtp.user_name` credential から取得（Gmailは From ヘッダが認証アカウントと一致している必要があるため、固定アドレスではなくここから参照している）
- [app/mailers/user_mailer.rb](../../app/mailers/user_mailer.rb) — 実際の送信処理

## 注意点

- **From アドレス:** Gmail SMTP は認証アカウントと異なる From アドレスを設定すると拒否・書き換えられることがあるため、送信元は常に手順2で使ったGmailアドレスになる
- **送信上限:** 個人Gmailアカウントは1日500通程度（Google Workspaceは2000通）。現状の用途では到達しない想定
- **初回アクセス時の確認:** Renderのサーバー（見慣れないIP）からの初回ログインをGoogleが「不審なアクセス」として一時的にブロック・確認を求めることがある。その場合はGoogleアカウントの通知から許可する
- **credentials.yml.enc の中身は絶対にコミットメッセージやログに平文で出力しない:** `git diff` はリポジトリの `.gitattributes` 設定（`diff=rails_credentials`）により自動で復号された差分を表示する。内容を確認する必要がある場合も、出力先には注意すること

## 動作確認

本番デプロイ後、ユニット/動向投稿フォームから実際に投稿し、admin宛にメールが届くことを確認する。
