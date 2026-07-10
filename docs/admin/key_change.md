# Admin — Person / Unit キー変更機能

## 概要

[issue #57](https://github.com/kuwavkdb/vkdby/issues/57) への対応。

`Person#key` / `Unit#key` は公開ページ URL（`/{key}`。ルーティング上のヘルパー名は `profile` だが、パスに `/profile/` は含まれない。[config/routes.rb:183](../../config/routes.rb#L183)）や他テーブルからの参照に使われる重要な識別子であるため、通常の編集フォームでは変更できないようにし、変更専用の操作（確認ダイアログ付き）としてのみ変更を許可する。キー変更時は、そのキーを参照している他テーブルのレコードも一括で追従させる。

---

## 用語

このドキュメントでは、キー変更前の値を指す用語として **`prev_key`** を使う。

既存の `old_key` カラム（旧サイト移行時に使われていたレガシー識別子。[person.rb](../../app/models/person.rb), [unit.rb](../../app/models/unit.rb)）とは無関係の別概念であり、混同を避けるため「旧キー」という言葉は使わない。

| 用語 | 意味 |
|---|---|
| `key` | 現在有効なキー |
| `prev_key` | 本機能でのキー変更によって置き換えられる直前のキー |
| `スタブレコード` | キー変更時に作成する、`key: prev_key` / `destination_key: 新キー` を持つ discard 済みのダミー People/Units レコード。旧キーへのアクセスをリダイレクトさせるためだけに存在する |
| `old_key`（既存・別物） | 旧サイト（〜vkdb.jp）時代に使われていたキー。本機能では一切変更しない |

---

## 対象範囲の調査結果

`key` を保持するのは `people.key` / `units.key` の2箇所（いずれも unique index）。これらを参照する他テーブルは以下の通り。

| 参照元テーブル / カラム | 対象 | 参照方式 | 備考 |
|---|---|---|---|
| `snapshot_people.person_key` | Person | 文字列コピー | `person_id` が未確定な場合の補助検索用（[snapshot_person.rb](../../app/models/snapshot_person.rb)） |
| `unit_people.person_key` | Person | 文字列コピー | 同上（[unit_person.rb](../../app/models/unit_person.rb)） |
| `items.artists`（jsonb 配列内の `key`） | Person / Unit 共通 | 文字列コピー | `Item.by_artist_key` スコープで検索（[item.rb](../../app/models/item.rb)） |

- `unit_key` という名前のカラムは存在しない。Unit と他テーブルの正式な関連付けは `unit_id` の外部キーで行われており、`unit_id` 自体はキー変更の影響を受けない。上記調査の通り、Unit の `key` を文字列として保持しているのは `items.artists` のみ。
- `trends.people` / `trends.units`（jsonb）は `person_id` / `unit_id` を保持しており、key への参照はないため対象外。

---

## アーキテクチャ

### 1. スタブレコードによるリダイレクト（既存 `destination_key` 機構の再利用）

`key` には unique index があるため、変更後は変更前の値で `find_by(key:)` してもヒットしなくなる。新規テーブルは追加せず、既存の `destination_key` によるリダイレクト機構（[`ProfilesController#show`](../../app/controllers/profiles_controller.rb#L4-L13)、統合・重複整理用途で既に稼働中）をそのまま再利用する。

```ruby
# ProfilesController#show（既存コード、変更なし）
@resource = Unit.with_discarded.includes(:links).find_by(key: params[:key]) ||
            Person.with_discarded.includes(:links).find_by(key: params[:key])
...
if @resource.destination_key.present?
  redirect_to profile_path(@resource.destination_key), status: :moved_permanently
  return
end
```

`with_discarded` かつ `destination_key.present?` を discard 済みかどうかのチェックより先に見ているため、**discard 済みのスタブレコードでも `destination_key` があればリダイレクトされる**。この既存の順序を利用する。

- キー変更時、`key: prev_key` / `destination_key: 新キー` を持つスタブレコードを People/Units テーブルに新規作成し、直後に `discard` する
- スタブレコードは `record.dup` をベースに作成し、以下を上書きする
  - `key`: `prev_key`
  - `destination_key`: 新キー
  - `old_key`: `nil`（unique index があるため、元レコードの `old_key` をそのまま複製すると一意制約違反になる）
  - `discarded_at`: 作成直後に `discard`
- Person / Unit で discard ベースの実装を共通化する（Unit には統合用の確立済みパターンとして `unit_type: moved`（discard せず `kept` のまま運用、`lib/tasks/import_moved.rake:57-68`）が既に存在するが、Person には `unit_type` に相当するカラムがなく同じパターンを使えないため、今回は Person/Unit 対称に discard ベースで統一する。`unit_type: moved` は既存の統合用途のまま温存し、本機能では使わない）
- discard により admin 側のデフォルト一覧・検索（`Person.kept` / `Unit.kept` 起点、[`admin/people_controller.rb`](../../app/controllers/admin/people_controller.rb#L8-L21), [`admin/units_controller.rb`](../../app/controllers/admin/units_controller.rb#L16-L27)）や公開側の一覧・検索・自動補完（`.kept` 起点）からは自動的に除外される
- 複数回リネームされた場合（A→B→C）、A へのアクセスは B を経由して C まで2ホップでリダイレクトされる（destination_key チェーンは既存の統合パターンでも起こり得る挙動であり、本機能固有の問題ではないため許容する）

### 2. `change_key!` によるキー更新とカスケード

`change_key!(new_key)` は Person / Unit で重複するため、`app/models/concerns/key_changeable.rb`（`KeyChangeable` concern, `ActiveSupport::Concern`）に共通実装として切り出し、両モデルに `include KeyChangeable` する。トランザクションで以下を行う。

1. `prev_key = key` を退避
2. `key_immutable` バリデーション（後述）を迂回する専用パスで、対象レコードの `key` カラムを `new_key` に更新（スタブ作成より先に行い、`prev_key` を一意制約上「空き」にする）
3. スタブレコードを作成し `discard`（前節参照）
4. `Item.by_artist_key(prev_key)` に該当する `items.artists` jsonb 配列内の `key` を `new_key` に書き換え（Person / Unit 共通、concern 内で実装）
5. `after_key_change(prev_key, new_key)` フック（concern 側は空実装）を呼ぶ。Person はこれをオーバーライドし、`SnapshotPerson.where(person_key: prev_key).update_all(person_key: new_key)` / `UnitPerson.where(person_key: prev_key).update_all(person_key: new_key)` を実行する。Unit は追従先テーブルがないためオーバーライド不要

### 3. 通常フォームでの変更禁止

- Person は既に `key_immutable` バリデーション（[person.rb:160](../../app/models/person.rb#L160)）で保護済み。`change_key!` はこのバリデーションを迂回する専用の内部フラグ `key_change_in_progress`（`KeyChangeable` concern が `attr_accessor` として定義し、`included do` ブロックで両モデルに付与）を使って更新する。
- Unit には同等のバリデーションがなかったため新規に追加した。また `Admin::UnitsController#unit_params`（`update` 用）から `:key` を除外する（`new`/`create` 用の許可は維持）。

### 4. 公開側コントローラーの discard 漏れ対応

discard 済みスタブレコードを新たに大量に作る運用が始まるため、既存コードのうち `.kept` を経由せず Person/Unit を検索・参照している箇所は、スタブレコードが意図せず表示されるリスクがある。本機能の実装と合わせて修正する。

| ファイル | 該当箇所 | 修正内容 |
|---|---|---|
| [`app/controllers/items_controller.rb`](../../app/controllers/items_controller.rb#L44-L58) | `filter_by_artist`。`Unit.find_by(key:)` / `Person.find_by(key:)` 等 | `.kept` を追加。スタブの `key`（`prev_key`）で直接ヒットしてしまうため実害あり |
| [`app/controllers/trends_controller.rb`](../../app/controllers/trends_controller.rb#L29) | `index` の `Unit.where(id: all_unit_ids)` | `.kept` を追加 |
| [`app/controllers/trends_controller.rb`](../../app/controllers/trends_controller.rb#L37-L40) | `show` の `Unit.where(id:)` / `Person.where(id:)` | `.kept` を追加 |
| [`app/controllers/custom_pages_controller.rb`](../../app/controllers/custom_pages_controller.rb#L48-L49) | `load_recent_trends` の `Unit.where(id:)` / `Person.where(id:)` | `.kept` を追加 |
| [`app/services/unit_graph_builder.rb`](../../app/services/unit_graph_builder.rb#L192) | `related_units = Unit.where(id: relevant_unit_ids)` | `.kept` を追加 |

`app/controllers/legacy_redirects_controller.rb` は `old_key` ベースの別用途（旧サイトからのリダイレクト）であり、スタブレコードの `old_key` は常に `nil` にするため影響を受けない。本対応の対象外とする。

### 5. `UpdateLog` への記録

`Admin::BaseController#record_update_log` は `action` に `'create'` / `'update'` 以外を渡すと `diff` が `nil` になる実装だったが、それ自体は問題ない（`diff` は nullable）。しかし `UpdateLog#action` の `validates :action, inclusion: { in: %w[create update discard undiscard] }` に `'change_key'` が含まれておらず、`change_key` アクションから `record_update_log(record, action: 'change_key')` を呼ぶと `UpdateLog.create!` が `ActiveRecord::RecordInvalid` を送出していた（`change_key!` 自体は正常終了した後に発生するため、キー変更は成功しているのにエラー画面が出るという紛らわしい不具合だった。実装時の手動確認で発覚）。

- `app/models/update_log.rb`: `validates :action, inclusion: { in: %w[create update discard undiscard change_key] }` に `change_key` を追加
- `app/controllers/admin/base_controller.rb`: `record_update_log` の `diff` 算出 `case` 文に `when 'update', 'change_key'` として `change_key` を追加し、`saved_changes` から diff を記録する

---

## 権限

- `change_key` アクションは `admin` ロールのみ許可する（`Admin::BaseController#require_admin` を使用。削除操作向けの `require_super_operator` より厳しいレベル）
- `docs/admin/permissions.md` に追記する

---

## UI/UX

- `units/_form.html.erb` の `key` 表示は `unit.new_record?` で分岐する（Person の [`people/_form.html.erb`](../../app/views/admin/people/_form.html.erb) も同様）。新規作成時は編集可能な `text_field`、保存済みレコードは readonly 表示 + 「キー変更」UI を表示する
- **フォームの入れ子問題**: `_form.html.erb` は丸ごと `form_with(model: [:admin, unit]) do |form| ... end` に包まれているため、その内部にキー変更用の `<form>` を直接書くと HTML として不正になる（`<form>` は入れ子にできない）。これを2つのパーシャルに分離して解決した
  - [`admin/shared/_change_key_trigger.html.erb`](../../app/views/admin/shared/_change_key_trigger.html.erb): 可視部品（「キー変更」ボタン・新キー入力欄・送信ボタン）。key フィールドのすぐ下、主フォームの**内側**に配置する。入力欄・送信ボタンには `form: form_id` オプション（HTML の `form` 属性）を付け、DOM 上の親子関係とは無関係に外側の別フォームへ送信されるようにする
  - [`admin/shared/_change_key_form.html.erb`](../../app/views/admin/shared/_change_key_form.html.erb): `id="change_key_form"` を持つだけの空の `<form>`（hidden の CSRF トークンのみ）。主フォームの**外側**（`edit.html.erb` 側、`render "form"` の呼び出しの外）に配置する。実際の送信先はこちら
  - 両パーシャルとも `current_user&.admin?` でガードする
- 「キー変更」ボタンはアンバー系の目立つボタン（アイコン付き）にし、押下で既存の [`toggle_controller.js`](../../app/javascript/controllers/toggle_controller.js) を使って入力欄を展開する（新規 JS 実装は不要）
- 送信ボタンには既存の確認ダイアログパターン（`onclick: "return confirm(...)"`、[people/edit.html.erb:18-21](../../app/views/admin/people/edit.html.erb#L18) 参照）を適用し、`document.getElementById('new_key').value` で入力された新キーの値を動的に埋め込んだ確認文言を表示する

> 初期実装ではキー変更UIをフォーム最下部（他の全項目の後）に置いていたが、「導線が分かりづらい」というフィードバックにより、key フィールド直下に移動し、ボタンも目立つスタイルに変更した。上記の構成は改善後のもの。

---

## 実装箇所

| 種別 | ファイル |
|---|---|
| model | `app/models/concerns/key_changeable.rb`（新規。`change_key!`, スタブ作成, `items.artists` 書き換え, `key_change_in_progress` フラグ、`after_key_change` フック） |
| model | `app/models/person.rb`（`include KeyChangeable`, `key_immutable` を `key_change_in_progress` 対応に修正, `after_key_change` で `snapshot_people`/`unit_people` を一括置換） |
| model | `app/models/unit.rb`（`include KeyChangeable`, `key_immutable` バリデーション新規追加） |
| model | `app/models/update_log.rb`（`action` の許可リストに `change_key` を追加） |
| routes | `config/routes.rb`（`admin/people`, `admin/units` に `member { patch :change_key }`） |
| controller | `app/controllers/admin/base_controller.rb`（`record_update_log` の diff 算出に `change_key` を追加） |
| controller | `app/controllers/admin/people_controller.rb`（`change_key` アクション。`person_params` から key 検証のため `update` 時のみ `:key` を除外） |
| controller | `app/controllers/admin/units_controller.rb`（`change_key` アクション、`unit_params` から `:key` 除外） |
| controller | `app/controllers/items_controller.rb`（`.kept` 追加） |
| controller | `app/controllers/trends_controller.rb`（`.kept` 追加） |
| controller | `app/controllers/custom_pages_controller.rb`（`.kept` 追加） |
| service | `app/services/unit_graph_builder.rb`（`.kept` 追加） |
| view | `app/views/admin/units/_form.html.erb`, `app/views/admin/people/_form.html.erb`（`new_record?` で readonly/編集可能を分岐、`_change_key_trigger` を key フィールド直下に配置） |
| view | `app/views/admin/shared/_change_key_trigger.html.erb`（新規。可視部品: ボタン・入力欄・確認ダイアログ） |
| view | `app/views/admin/shared/_change_key_form.html.erb`（新規。送信先の空フォーム） |
| view | `app/views/admin/people/edit.html.erb`, `app/views/admin/units/edit.html.erb`（`_change_key_form` を主フォームの外側に配置） |
| docs | `docs/admin/permissions.md`（`change_key` の権限追記） |

`ProfilesController#show` 自体の変更は不要（既存の `destination_key` リダイレクトロジックをそのまま利用するため）。

### 関連して見つかった別issue

- **[#878](https://github.com/kuwavkdb/vkdby/issues/878)**: 本対応とは別に、`/admin/people/new` から key を持つ Person を新規作成する手段がそもそも存在しないバグを発見し、別issue・別PRで修正した。Unit で「新規作成時のみ編集可・保存後は readonly」というパターンを実装した際に Person 側の現状を確認して発覚したもので、`person_params` への `:key` 追加と `people/_form.html.erb` の `new_record?` 分岐が対応内容（結果的に Unit と同じパターンになっている）。本ドキュメントの Step 2 時点では「Person は既に key 保護済み」という前提だったが、実際には新規作成の導線が欠けていた。
- **websocket-driver の脆弱性対応**: 実装中の CI（`bundler-audit`）で `actioncable` が依存する `websocket-driver` の新規CVEを検知し、無関係の別PRとして先に develop へ修正を取り込んだ（本機能のコードとは無関係）。

---

## 実装ステップ

依存関係のない Step 1・2 は他のステップに先行して着手・レビュー可能。Step 3 以降は Step 1・2 の完了を前提とする。各ステップにテストを含める。

### Step 1: 公開側の discard 漏れ修正（先行対応・独立）
- `items_controller.rb` / `trends_controller.rb` / `custom_pages_controller.rb` / `unit_graph_builder.rb` に `.kept` を追加
- 現時点ではスタブレコードが存在しないため regression にはならない、安全に先行マージ可能
- テスト: 該当箇所の feature/request スペックで discard 済みレコードが除外されることを確認

### Step 2: Unit の key 保護（先行対応・独立）
- `Unit` に `key_immutable` バリデーションを追加（[person.rb:160](../../app/models/person.rb#L160) を参考に）
- `Admin::UnitsController#unit_params`（`update` 用）から `:key` を除外
- `units/_form.html.erb` の `key` を `new_record?` の場合のみ編集可能にし、それ以外は readonly 表示に変更（[people/_form.html.erb](../../app/views/admin/people/_form.html.erb) を参考に）
- テスト: 通常の `update` で `key` が変更されないこと、既存の Unit 更新スペックが壊れないこと
- **実施結果**: Unit にこのパターンを実装した際、Person 側は「新規作成時も含めて常に readonly」になっており `/admin/people/new` から key を設定する手段が無いことが判明。これは本Stepとは別のバグとして [#878](https://github.com/kuwavkdb/vkdby/issues/878) で追跡し、別PRで修正した（`person_params` に `:key` を追加、`people/_form.html.erb` に `new_record?` 分岐を追加。結果的に Unit と同じパターンになった）

### Step 3: `change_key!` のモデル実装
- `Person#change_key!` / `Unit#change_key!` を追加（スタブレコード生成・discard・カスケード更新を含む）
- バリデーション迂回用の内部フラグ（`key_change_in_progress` 等）を追加
- テスト: スタブレコードが `discard` 済み・`destination_key` 設定済みで作成されること、`snapshot_people`/`unit_people`/`items.artists` が一括置換されること、`change_key!` を経由しない通常の `update` では `key` が変更できないこと
- **実施結果**: Person/Unit で実装が重複するため、`app/models/concerns/key_changeable.rb`（`KeyChangeable` concern）として共通化した（「アーキテクチャ」節参照）

### Step 4: admin コントローラー / ルーティングの配線
- `config/routes.rb` に `member { patch :change_key }` を `admin/people`, `admin/units` へ追加
- `Admin::PeopleController#change_key` / `Admin::UnitsController#change_key` を追加し `require_admin` を適用
- テスト: 権限制御（admin 以外は拒否）、重複キー指定時のバリデーションエラー
- **実施結果**: ローカルでの手動確認で、`change_key!` 自体は成功しているのに `UpdateLog` 記録が `RecordInvalid` で失敗し紛らわしいエラーが表示される不具合を発見・修正（「アーキテクチャ」節「5. `UpdateLog` への記録」参照）。この不具合はテストでは検出されず（成功時とエラー時のリダイレクト先が同じだったため）、修正時にテストを強化した

### Step 5: 管理画面 UI
- `people/_form.html.erb` / `units/_form.html.erb`（または edit 画面）に「キー変更」ボタン、`toggle_controller` による入力欄の展開、`confirm()` 付き送信ボタンを追加
- ブラウザでの動作確認（ボタン押下→入力→確認ダイアログ→変更後のリダイレクト確認まで一通り）
- **実施結果**: 初期実装ではボタンをフォーム最下部に置いていたが、「導線が分かりづらい」というフィードバックを受けて key フィールド直下に移動。フォームの入れ子ができない制約から `_change_key_trigger` / `_change_key_form` の2パーシャルに分離する構成になった（詳細は「UI/UX」節参照）

### Step 6: リダイレクト経路の確認
- `ProfilesController#show` はコード変更不要だが、スタブレコード経由の 301 リダイレクトが期待通り動くことをテストで確認
- 複数回リネーム（A→B→C）で `/A` へのアクセスが 2 ホップで `/C` に到達することを確認

### Step 7: ドキュメント更新
- `docs/admin/permissions.md` に `change_key` アクションの権限（admin のみ）を追記

---

## テスト方針

- モデルスペック: `change_key!` によるスタブレコード作成（discard済み・`destination_key` 設定済み）・`snapshot_people`/`unit_people`/`items.artists` の一括置換・通常の `update` では `key` が変更できないこと
- コントローラー / リクエストスペック: `change_key` アクションの権限制御、重複キー時のエラー
- `ProfilesController#show` のスタブレコード経由リダイレクト（複数回リネームで2ホップになるケースを含む）
- `items_controller` / `trends_controller` / `custom_pages_controller` / `unit_graph_builder` の discard 済みスタブレコード除外
