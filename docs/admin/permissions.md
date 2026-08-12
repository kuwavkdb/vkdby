# 管理画面の権限設計

## ロール一覧

`users.role` カラム（integer）で管理。デフォルトは `operator`。

| ロール | 値 | メソッド |
|---|---|---|
| `operator` | 0 | — |
| `super_operator` | 1 | `super_operator_or_above?` |
| `admin` | 2 | `admin?`、`super_operator_or_above?` |

`super_operator_or_above?` は `super_operator` と `admin` の両方が `true` になる。

---

## 機能別アクセス制限

### 全員（ログイン済み）

`Admin::BaseController` の `before_action :require_login` で全アクション共通。

| 機能 | アクション |
|---|---|
| Units — 閲覧・作成・編集 | index / new / create / edit / update / show / search |
| People — 閲覧・作成・編集 | index / new / create / edit / update / search |
| Index Groups / タグ（Tag Indices）— 閲覧・作成・編集・削除・並べ替え・グループ移動 | 全アクション |
| Trends — 閲覧・作成・編集 | index / new / create / edit / update |
| External Sites | 全アクション |
| Custom Pages — 閲覧・作成・編集 | index / new / create / edit / update |
| Custom Pages — サーバーサイドプレビュー（`{{include}}`/`{{snapshot}}`/`{{item}}` 等のプラグイン記法を反映） | preview |
| Sections — 全操作 | new / create / edit / update / destroy / undiscard / reorder |
| Unit Logs / Person Logs | 閲覧 |

### super_operator 以上

| 機能 | アクション |
|---|---|
| Units — 削除・復元 | destroy / undiscard |
| People — 削除 | destroy |
| Trends — 削除 | destroy |
| Items — 閲覧・作成・編集 | index / new / create / edit / update |
| Items — アーティスト一括変更（index にアーティスト検索条件がある場合のみUI表示） | bulk_artist_update |
| Custom Pages — 削除・復元 | destroy / undiscard |
| Update Logs — 全操作 | 全アクション（restore 含む） |
| Unit Snapshots — スナップショット作成 | create |

### admin のみ

| 機能 | アクション |
|---|---|
| **画像管理**（`/admin/images`） | index / show / destroy（全アクション） |
| **画像アップロード**（Section 編集） | upload_image |
| **画像アップロード**（Custom Page 編集） | upload_image |
| Items — 削除 | destroy |
| Users 管理 | 全アクション |
| Operation Logs（ログイン履歴） | index（全アクション） |
| Wiki Page Imports | 全アクション |
| Units / People — キー変更 | change_key |
| Units / People — リダイレクト元の物理削除 | purge |
| Units / People — 一覧からのStatus一括更新 | bulk_update_status |

---

## 画像機能の権限まとめ

画像アップロード・管理は admin 専用。

| 場所 | 制限 |
|---|---|
| Section 編集画面のアップロードボタン | `current_user.admin?` のときのみ表示 |
| Custom Page 編集画面のアップロードボタン | `current_user.admin?` のときのみ表示 |
| `POST /admin/sections/:id/upload_image` | `require_admin` |
| `POST /admin/custom_pages/:id/upload_image` | `require_admin` |
| `/admin/images`（一覧・詳細・削除） | `require_admin` |
| ナビゲーションの Images リンク | `current_user.admin?` のときのみ表示 |

---

## ビュー側の表示制御

コントローラーのアクセス制限に加え、ビューでもボタン・リンクの表示を制御している。

| 条件 | 非表示になる操作 |
|---|---|
| `super_operator_or_above?` でない | Units / People / Trends / Custom Pages の削除・復元ボタン |
| `super_operator_or_above?` でない | Items の新規作成・編集ボタン |
| `super_operator_or_above?` でない | 画像管理の削除ボタン |
| `admin?` でない | Section / Custom Page 編集画面のアップロードボタン |
| `admin?` でない | ナビの Images リンク |
| `admin?` でない | Units / People 編集画面の「キー変更」ボタン |
| `admin?` でない | Units / People 一覧のリダイレクト元「物理削除」ボタン |
| `admin?` でない | Units / People 一覧のチェックボックス・一括Status更新バー |

---

## 実装箇所

- ロール定義: `app/models/user.rb`
- 権限チェックメソッド: `app/controllers/admin/base_controller.rb`
- 各コントローラーの `before_action`: `app/controllers/admin/` 以下
- ログイン履歴（`OperationLog`）の記録: `app/controllers/sessions_controller.rb`（ログイン成功時）
- ログイン履歴の参照: `app/controllers/admin/operation_logs_controller.rb`（`require_admin`）
