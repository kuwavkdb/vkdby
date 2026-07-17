# Issue #928: ログインのログ機能 実装プラン

## Issue概要
- `operation_logs` テーブルを新設し、重要なユーザーオペレーションを記録する。
- まずは `operation_type = "login"` を記録する。
- admin ユーザーのみが参照可能な、ユーザーのログイン履歴機能を追加する。

## 未確定事項（着手前に確認したい点）
- ログイン**失敗**時も記録するか（issue文面からは成功ログインのみと解釈）。
  → 今回は成功ログインのみを対象とする前提でプランを作成。失敗も記録する場合は `user_id` を optional にする必要あり。
- IPアドレス・User-Agent も記録するか（一般的な「ログイン履歴」機能では有用だが issue に明記なし）。
  → 今回は含めない前提。必要なら追加カラムとして後日拡張可能な設計にする。

---

## 1. マイグレーション

新規ファイル: `db/migrate/YYYYMMDDHHMMSS_create_operation_logs.rb`

```ruby
class CreateOperationLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :operation_logs do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :operation_type, null: false
      t.datetime :created_at, null: false
    end

    add_index :operation_logs, :operation_type
    add_index :operation_logs, :created_at
  end
end
```

- `update_logs` テーブルの構造（`created_at` のみで `updated_at` なし、`user_id` に FK・インデックス）に倣う。
- `t.references :user` に `index: true` を明示し、`user_id` にもインデックスを張る（`update_logs` の `index_update_logs_on_user_id` と同じ構成）。
- `updated_at` は不要（ログは追記のみで更新しないため）。

---

## 2. モデル

新規ファイル: `app/models/operation_log.rb`

```ruby
class OperationLog < ApplicationRecord
  belongs_to :user

  OPERATION_TYPES = %w[login].freeze

  validates :operation_type, inclusion: { in: OPERATION_TYPES }
end
```

- `UpdateLog#action` の `validates :action, inclusion: { in: %w[...] }` パターンを踏襲。
- 将来オペレーション種別を増やす際は `OPERATION_TYPES` に追記するだけで済む設計。

`app/models/user.rb` に関連を追加:
```ruby
has_many :operation_logs, dependent: :destroy
```

---

## 3. ログイン時の記録

`app/controllers/sessions_controller.rb` の `create` アクションを修正:

```ruby
def create
  user = User.find_by(email: params[:email])
  if user&.authenticate(params[:password])
    session[:user_id] = user.id
    OperationLog.create!(user: user, operation_type: 'login')
    redirect_to session.delete(:return_to) || root_path, notice: 'ログインしました'
  else
    flash.now[:alert] = 'メールアドレスまたはパスワードが正しくありません'
    render :new, status: :unprocessable_entity
  end
end
```

- 認証成功後、セッション確立と同じタイミングで記録する。
- 記録処理の失敗でログイン自体を失敗させたくないため、`create!` の例外はそのまま気にしない（DB制約違反以外は基本発生しない想定）。過剰な防御的 rescue は追加しない。

---

## 4. 管理画面: 参照機能（admin専用）

### ルーティング
`config/routes.rb` の `namespace :admin do ... end` 内、`resources :users` の近くに追加:

```ruby
resources :operation_logs, only: %i[index]
```

### コントローラー
新規ファイル: `app/controllers/admin/operation_logs_controller.rb`

```ruby
module Admin
  class OperationLogsController < Admin::BaseController
    before_action :require_admin

    def index
      @operation_logs = OperationLog.includes(:user).order(created_at: :desc)
    end
  end
end
```

- `Admin::BaseController` の `require_login` は既に効いているため、`require_admin` の `before_action` を追加するだけでよい（`Admin::UsersController` と同じパターン）。
- 一覧のみで十分（作成・編集・削除は不要 = ログは改ざん不可であるべき）。

### ビュー
新規ファイル: `app/views/admin/operation_logs/index.html.erb`

- `app/views/admin/unit_logs/index.html.erb` / `_list.html.erb` のテーブル形式を踏襲。
- 表示カラム: 発生日時（`created_at`）／ユーザー名・メールアドレス／操作種別（`operation_type`）。
- 件数が多くなる想定のため、`kaminari` 等既存のページネーション手段があれば流用（他の index で使用しているものを確認して合わせる）。
- アクセシビリティ: テーブルは `<th scope="col">` を使用し、他の管理画面一覧と同じコントラスト・フォーカス指針に従う。

---

## 5. ナビゲーション

`app/views/layouts/application.html.erb` の admin ドロップダウン内、デスクトップ版（`admin_users_path` の直前、約194行目）とモバイル版（約354行目）の2箇所に、`current_user.admin?` の場合のみ表示するリンクを追加する。

```erb
<% if current_user.admin? %>
  <%= link_to admin_operation_logs_path, class: "..." do %>
    ...
  <% end %>
<% end %>
```

- 既存の「Images」リンクが `admin?` 限定で条件分岐しているので、そのパターンに倣う。

---

## 6. ドキュメント更新（CLAUDE.md指示に基づく必須対応）

`docs/admin/permissions.md` の「admin のみ」セクションの表に追記:

| 機能 | アクション |
|---|---|
| Operation Logs（ログイン履歴） | index（全アクション） |

「実装箇所」セクションにも `OperationLog` 関連の記述を追加する。

---

## 7. テスト

- モデルスペック: `OperationLog` の validation（`operation_type` の inclusion）。
- リクエスト/コントローラースペック:
  - ログイン成功時に `OperationLog` が1件作成されること。
  - ログイン失敗時には作成されないこと。
  - `Admin::OperationLogsController#index` が admin 以外（未ログイン／operator／super_operator）からのアクセスで拒否されること。
  - admin からのアクセスでは一覧が表示されること。
- 既存のテストフレームワーク（RSpec想定、`spec/` 配下の既存パターンに合わせる）を確認して同じ書式で追加する。

---

## 実装順序（チェックリスト）

1. [ ] マイグレーション作成・実行（`bundle exec rails db:migrate`）
2. [ ] `OperationLog` モデル作成 + `User#operation_logs` 関連追加
3. [ ] `SessionsController#create` に記録処理を追加
4. [ ] `Admin::OperationLogsController` 追加 + ルーティング追加
5. [ ] `admin/operation_logs/index.html.erb` ビュー作成
6. [ ] ナビゲーションに admin 限定リンク追加（デスクトップ・モバイル両方）
7. [ ] `docs/admin/permissions.md` 更新
8. [ ] テスト追加（モデル・コントローラー）
9. [ ] ブランチ `feat/issue-928-operation-logs-login` を `develop` から作成し PR 作成

---

## 影響範囲まとめ

| ファイル | 変更内容 |
|---|---|
| `db/migrate/xxx_create_operation_logs.rb` | 新規 |
| `app/models/operation_log.rb` | 新規 |
| `app/models/user.rb` | `has_many :operation_logs` 追加 |
| `app/controllers/sessions_controller.rb` | ログイン成功時に記録処理追加 |
| `app/controllers/admin/operation_logs_controller.rb` | 新規 |
| `app/views/admin/operation_logs/index.html.erb` | 新規 |
| `config/routes.rb` | `resources :operation_logs, only: %i[index]` 追加 |
| `app/views/layouts/application.html.erb` | admin限定ナビリンク追加（2箇所） |
| `docs/admin/permissions.md` | admin専用機能として追記 |
| `spec/...` | モデル・コントローラーのテスト追加 |
