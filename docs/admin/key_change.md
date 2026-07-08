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

`Person#change_key!(new_key)` / `Unit#change_key!(new_key)` をトランザクションで実装する。

1. `prev_key = key` を退避
2. `key_immutable` バリデーション（後述）を迂回する専用パスで、対象レコードの `key` カラムを `new_key` に更新（スタブ作成より先に行い、`prev_key` を一意制約上「空き」にする）
3. スタブレコードを作成し `discard`（前節参照）
4. 参照先テーブルの一括置換
   - Person: `SnapshotPerson.where(person_key: prev_key).update_all(person_key: new_key)` / `UnitPerson.where(person_key: prev_key).update_all(person_key: new_key)`
   - Person / Unit 共通: `Item.by_artist_key(prev_key)` に該当する `items.artists` jsonb 配列内の `key` を `new_key` に書き換え

### 3. 通常フォームでの変更禁止

- Person は既に `key_immutable` バリデーション（[person.rb:159](../../app/models/person.rb#L159)）で保護済み。`change_key!` はこのバリデーションを迂回する専用の内部フラグ（例: `attr_accessor :key_change_in_progress`）を使って更新する。
- Unit には同等のバリデーションがまだ無いため新規に追加する。また `Admin::UnitsController#unit_params`（`update` 用）から `:key` を除外する（`new`/`create` 用の許可は維持）。

### 4. 公開側コントローラーの discard 漏れ対応

discard 済みスタブレコードを新たに大量に作る運用が始まるため、既存コードのうち `.kept` を経由せず Person/Unit を検索・参照している箇所は、スタブレコードが意図せず表示されるリスクがある。本機能の実装と合わせて修正する。

| ファイル | 該当箇所 | 修正内容 |
|---|---|---|
| [`app/controllers/items_controller.rb`](../../app/controllers/items_controller.rb#L39-L49) | `filter_by_artist`。`Unit.find_by(key:)` / `Person.find_by(key:)` 等 | `.kept` を追加。スタブの `key`（`prev_key`）で直接ヒットしてしまうため実害あり |
| [`app/controllers/trends_controller.rb`](../../app/controllers/trends_controller.rb#L27) | `index` の `Unit.where(id: all_unit_ids)` | `.kept` を追加 |
| [`app/controllers/trends_controller.rb`](../../app/controllers/trends_controller.rb#L33-L36) | `show` の `Unit.where(id:)` / `Person.where(id:)` | `.kept` を追加 |
| [`app/controllers/custom_pages_controller.rb`](../../app/controllers/custom_pages_controller.rb#L44-L45) | `load_recent_trends` の `Unit.where(id:)` / `Person.where(id:)` | `.kept` を追加 |
| [`app/services/unit_graph_builder.rb`](../../app/services/unit_graph_builder.rb#L192) | `related_units = Unit.where(id: relevant_unit_ids)` | `.kept` を追加 |

`app/controllers/legacy_redirects_controller.rb` は `old_key` ベースの別用途（旧サイトからのリダイレクト）であり、スタブレコードの `old_key` は常に `nil` にするため影響を受けない。本対応の対象外とする。

---

## 権限

- `change_key` アクションは `admin` ロールのみ許可する（`Admin::BaseController#require_admin` を使用。削除操作向けの `require_super_operator` より厳しいレベル）
- `docs/admin/permissions.md` に追記する

---

## UI/UX

- `units/_form.html.erb` の `key` 表示を、Person 側（[`people/_form.html.erb`](../../app/views/admin/people/_form.html.erb)）と同様の readonly 表示に変更する
- 編集画面に「キー変更」ボタンを設置し、クリックで入力欄を展開する（既存の [`toggle_controller.js`](../../app/javascript/controllers/toggle_controller.js) を流用、新規 JS 実装は不要）
- 送信ボタンには既存の確認ダイアログパターン（`onclick: "return confirm(...)"`、[people/edit.html.erb:18-21](../../app/views/admin/people/edit.html.erb#L18) 参照）を適用し、新しいキーを埋め込んだ確認文言を表示する

---

## 実装箇所（予定）

| 種別 | ファイル |
|---|---|
| model | `app/models/person.rb`（`change_key!`, スタブ作成, `key_change_in_progress` フラグ） |
| model | `app/models/unit.rb`（`change_key!`, スタブ作成, `key_immutable` バリデーション追加） |
| routes | `config/routes.rb`（`admin/people`, `admin/units` に `member { patch :change_key }`） |
| controller | `app/controllers/admin/people_controller.rb`（`change_key` アクション） |
| controller | `app/controllers/admin/units_controller.rb`（`change_key` アクション、`unit_params` から `:key` 除外） |
| controller | `app/controllers/items_controller.rb`（`.kept` 追加） |
| controller | `app/controllers/trends_controller.rb`（`.kept` 追加） |
| controller | `app/controllers/custom_pages_controller.rb`（`.kept` 追加） |
| service | `app/services/unit_graph_builder.rb`（`.kept` 追加） |
| view | `app/views/admin/units/_form.html.erb`（readonly 化） |
| view | `app/views/admin/people/_form.html.erb`, `app/views/admin/units/_form.html.erb`（キー変更ボタン・入力欄） |
| docs | `docs/admin/permissions.md`（`change_key` の権限追記） |

`ProfilesController#show` 自体の変更は不要（既存の `destination_key` リダイレクトロジックをそのまま利用するため）。

---

## 実装ステップ

依存関係のない Step 1・2 は他のステップに先行して着手・レビュー可能。Step 3 以降は Step 1・2 の完了を前提とする。各ステップにテストを含める。

### Step 1: 公開側の discard 漏れ修正（先行対応・独立）
- `items_controller.rb` / `trends_controller.rb` / `custom_pages_controller.rb` / `unit_graph_builder.rb` に `.kept` を追加
- 現時点ではスタブレコードが存在しないため regression にはならない、安全に先行マージ可能
- テスト: 該当箇所の feature/request スペックで discard 済みレコードが除外されることを確認

### Step 2: Unit の key 保護（先行対応・独立）
- `Unit` に `key_immutable` バリデーションを追加（[person.rb:159](../../app/models/person.rb#L159) を参考に）
- `Admin::UnitsController#unit_params`（`update` 用）から `:key` を除外
- `units/_form.html.erb` の `key` を readonly 表示に変更（[people/_form.html.erb](../../app/views/admin/people/_form.html.erb) を参考に）
- テスト: 通常の `update` で `key` が変更されないこと、既存の Unit 更新スペックが壊れないこと

### Step 3: `change_key!` のモデル実装
- `Person#change_key!` / `Unit#change_key!` を追加（スタブレコード生成・discard・カスケード更新を含む）
- バリデーション迂回用の内部フラグ（`key_change_in_progress` 等）を追加
- テスト: スタブレコードが `discard` 済み・`destination_key` 設定済みで作成されること、`snapshot_people`/`unit_people`/`items.artists` が一括置換されること、`change_key!` を経由しない通常の `update` では `key` が変更できないこと

### Step 4: admin コントローラー / ルーティングの配線
- `config/routes.rb` に `member { patch :change_key }` を `admin/people`, `admin/units` へ追加
- `Admin::PeopleController#change_key` / `Admin::UnitsController#change_key` を追加し `require_admin` を適用
- テスト: 権限制御（admin 以外は拒否）、重複キー指定時のバリデーションエラー

### Step 5: 管理画面 UI
- `people/_form.html.erb` / `units/_form.html.erb`（または edit 画面）に「キー変更」ボタン、`toggle_controller` による入力欄の展開、`confirm()` 付き送信ボタンを追加
- ブラウザでの動作確認（ボタン押下→入力→確認ダイアログ→変更後のリダイレクト確認まで一通り）

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
