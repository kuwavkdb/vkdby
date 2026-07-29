# Issue #953: カスタムページにバンドのスナップショットを埋め込む機能 実装プラン

## Issue概要
- `{{snapshot key, snapshot_id}}` のような記法で、カスタムページ本文に指定したバンドの特定のラインアップスナップショットを埋め込めるようにする。
- 準備1: `{{プラグイン名称 パラメータ}}` という記法を汎用的な「カスタムプラグイン」記法として確立する（既存の `{{include ...}}` はこの一種として位置づけ直す）。
- 準備2: 管理画面のスナップショット一覧に ID を表示し、`snapshot_id` を埋め込み記法にコピーしやすくする。

## 現状の実装（調査結果）
- `{{include ...}}` は [application_helper.rb](../../app/helpers/application_helper.rb) の `markdown(text, sectionable:)`（79〜91行）→ `expand_include_macros`（104〜127行）で専用のgsub正規表現 `/\{\{include\s+(?:([a-z0-9_:-]*),)?(.+?)\}\}/` により実装されている。プラグイン名で分岐する汎用機構にはなっていない。
- [custom_page.rb](../../app/models/custom_page.rb) の `rebuild_include_relations`（54〜65行）・`no_circular_includes`（69〜82行）は `{{include key,section}}` 専用の正規表現で `body` をスキャンし、`CustomPageInclude` 中間テーブルへの記録・循環参照チェックを行っている。これは include 固有の仕組みであり、snapshot 埋め込みには不要（ページ間参照ではないため）。
- `Unit` は `key`（string, unique index）でバンドを一意に特定できる。`UnitSnapshot` は `belongs_to :unit` で `unit_id, snapshot_date, label, current, past, snapshot_index` を持ち、`has_many :snapshot_people` でメンバー構成を保持（画像はなし、テキスト情報のみ）。
- 公開画面での表示は [profiles/show.html.erb:70](../../app/views/profiles/show.html.erb) の `render UnitSnapshotsComponent.new(snapshots: @snapshots, unit: @resource, admin: ...)`。`@snapshots` は [profiles_controller.rb:93-96](../../app/controllers/profiles_controller.rb) で `unit.unit_snapshots.active.includes(:snapshot_people).order(...)` と組み立てられており、**`active` スコープのみが公開対象**。
- `UnitSnapshotsComponent` は `snapshots:` に配列を渡す設計（`@snapshots.each` でループ）なので、単一スナップショットを `[snapshot]` として渡せばそのまま流用できる。
- 管理画面のスナップショット一覧 [admin/unit_snapshots/index.html.erb](../../app/views/admin/unit_snapshots/index.html.erb) とユニット編集画面内の一覧 [admin/units/_snapshots_list.html.erb](../../app/views/admin/units/_snapshots_list.html.erb) はどちらも ID 列を表示していない。
- CustomPage の `body` 編集は `Admin::BaseController` の `require_login` のみが効いており、operator 以上の全ログインユーザーが編集可能（`require_admin`/`require_super_operator` は他アクション限定）。→ 今回の変更で権限・管理画面機能が新規追加/変更されるわけではないため、`docs/admin/permissions.md` の更新は不要と判断（CLAUDE.md の要求は「新機能追加・権限変更時」）。
- `expand_include_macros` 専用のテストは現状存在しない（`test/`配下に無し）。

## 未確定事項（着手前に確認したい点）
1. 埋め込み対象を `active`（公開）スナップショットのみに限定する前提で進めるが、非公開スナップショットを敢えて埋め込みたいケースがあるか？ → 一旦「公開プロフィールと同じ範囲」に統一する前提でプランを作成。
2. スナップショットが見つからない場合（key/idが誤り、非公開等）の挙動 → `include` と同様に**空文字でサイレントに何も表示しない**方針とするが、管理者が原因に気付けないため、代わりにHTMLコメント（画面には出ない）でデバッグ用の理由を残す案もある。今回はシンプルに空文字を採用する前提。
3. 汎用プラグイン記法の一般化範囲 → 本issueでは `include` と `snapshot` の2種類をディスパッチできる最小限の汎用化に留め、将来のプラグイン追加を見据えた設計（ハンドラー登録テーブル）にする。過剰な汎用化（設定ファイル化等）はしない。

---

## 1. プラグイン記法の汎用化（準備1）

[application_helper.rb](../../app/helpers/application_helper.rb) の `expand_include_macros` を汎用の `expand_plugin_macros` に置き換える。

```ruby
def markdown(text, sectionable: nil)
  return '' if text.blank?

  text = expand_plugin_macros(text, sectionable:)

  renderer = ExternalAwareHtmlRenderer.new(site_host: request.host, hard_wrap: true)
  Redcarpet::Markdown.new(renderer, ...).render(text).html_safe
end

private

# {{プラグイン名 パラメータ}} 形式の記法をディスパッチする
PLUGIN_HANDLERS = {
  'include' => :expand_include_plugin,
  'snapshot' => :expand_snapshot_plugin
}.freeze

def expand_plugin_macros(text, sectionable:)
  text.gsub(/\{\{(\w[\w-]*)\s+(.+?)\}\}/m) do
    plugin_name = Regexp.last_match(1)
    args = Regexp.last_match(2).strip
    handler = PLUGIN_HANDLERS[plugin_name]
    handler ? send(handler, args, sectionable) : Regexp.last_match(0)
  end
end

# {{include key,セクション名}} 等（既存ロジックをそのまま移設）
def expand_include_plugin(args, sectionable)
  identifier, section_name = args.include?(',') ? args.split(',', 2) : [nil, args]
  identifier = identifier&.strip
  section_name = section_name.strip

  owner = if identifier.nil? || identifier.empty?
            sectionable
          elsif identifier.start_with?('unit:')
            Unit.find_by(id: identifier.delete_prefix('unit:'))
          elsif identifier.start_with?('person:')
            Person.find_by(id: identifier.delete_prefix('person:'))
          else
            CustomPage.published.find_by(key: identifier)
          end

  section = owner&.sections&.kept&.find_by(name: section_name)
  section&.markdown.presence || section&.wiki_text.presence || ''
end
```

- 正規表現を `\{\{include\s+...` から `\{\{(\w[\w-]*)\s+(.+?)\}\}` に一般化。未登録のプラグイン名（例: 本文中にたまたま `{{foo bar}}` と書かれた場合）は**マッチした文字列をそのまま残す**ことで、既存本文への影響・意図しない消失を防ぐ。
- `custom_page.rb` の `rebuild_include_relations` / `no_circular_includes` は `include` 固有の正規表現スキャンのままで変更不要（挙動に影響なし）。

---

## 2. snapshot プラグインの実装（本題）

同じく `application_helper.rb` に追加:

```ruby
# {{snapshot ユニットkey,snapshot_id}}
def expand_snapshot_plugin(args, _sectionable)
  unit_key, snapshot_id = args.split(',', 2).map(&:strip)
  return '' if unit_key.blank? || snapshot_id.blank?

  unit = Unit.kept.find_by(key: unit_key)
  snapshot = unit&.unit_snapshots&.active&.find_by(id: snapshot_id)
  return '' unless snapshot

  render(UnitSnapshotsComponent.new(snapshots: [snapshot], unit: unit, admin: false)).to_s
end
```

- `ApplicationHelper` は View コンテキストに mixin されるため、helperメソッド内から `render(component)` を呼び出せる（`custom_pages#show` から `markdown(@page.body, ...)` 経由で呼ばれる際、`self` は ActionView コンテキスト）。
- `unit.unit_snapshots.active.find_by(id: ...)` とすることで、①指定バンド以外のIDを誤って参照できない、②非公開スナップショットは埋め込めない、の2点を保証する。
- レンダリングされるHTML（Tailwindクラス・Stimulus `data-controller="toggle"`・`hx-get` 属性）をMarkdown原文に差し込んだ後にRedcarpetでパースする点は `include` と同じ経路。Redcarpetは `escape_html: false`（デフォルト）のためHTMLブロックはそのまま通過するが、**マクロ行の前後に空行が必要**（Markdownの生HTMLブロック認識ルール）。この制約はCustomPage編集画面のヘルプ文言に追記するか、動作確認時にユーザーへ伝える。
- `snapshot_members_path`（過去スナップショットの `hx-get` 遅延ロード）は `unit.key` を使うため、埋め込みでも正しく動作する見込み（[routes.rb:189-190](../../config/routes.rb) / [profiles_controller.rb:66-74](../../app/controllers/profiles_controller.rb)）。追加対応不要。

---

## 3. 管理画面: スナップショット一覧にID表示（準備2）

### [app/views/admin/unit_snapshots/index.html.erb](../../app/views/admin/unit_snapshots/index.html.erb)
- ヘッダー行（20〜24行目）の先頭に `<th scope="col">ID</th>` を追加。
- ボディ行（33〜41行目付近）の先頭に `<td><%= snapshot.id %></td>` を追加。

### [app/views/admin/units/_snapshots_list.html.erb](../../app/views/admin/units/_snapshots_list.html.erb)
- 同様にヘッダー（19〜23行目）とボディ（36〜44行目）にID列を追加。
- 既に `data-id="<%= snapshot.id %>"` が `<tr>` に付与されている（30行目）ので、視認性目的でテキスト表示のID列を追加する。

いずれもアクセシビリティ的には `<th scope="col">ID</th>` を使うだけで問題なし（既存パターン踏襲）。

---

## 4. テスト

- 新規: `test/helpers/application_helper_test.rb`（既存テストがMinitest構成なので合わせる）
  - `expand_plugin_macros` の回帰テスト: `{{include ...}}` が従来通り動作すること。
  - 未登録プラグイン名（`{{unknown foo}}`）がそのまま残ること。
  - `{{snapshot key,id}}`:
    - 正常系: 対応する `Unit`/`UnitSnapshot`（`active: true`）が存在する場合にコンポーネントの内容（メンバー名等）がHTMLに含まれること。
    - 異常系: `key` が存在しない／`snapshot_id` が別ユニットのもの／`active: false` の場合に空文字になること。
- 既存 `test/controllers/custom_pages_controller_test.rb` に、`body` に `{{snapshot ...}}` を含むCustomPageを表示した際のE2E的な確認を1件追加。

---

## 5. ドキュメント更新

- `docs/admin/permissions.md`: 新規の管理画面機能・権限変更ではないため更新不要（CustomPage編集権限は変更なし、スナップショット一覧はID列追加のみ）。
- CustomPage編集画面（管理画面）にプラグイン記法のヘルプテキストがあれば、`{{snapshot key, snapshot_id}}` の説明を追記する（該当箇所は要確認。無ければ本issueのスコープ外として見送り可）。

---

## 実装順序（チェックリスト）

1. [ ] `application_helper.rb`: `expand_include_macros` → `expand_plugin_macros` + `expand_include_plugin` へリファクタリング（既存挙動を壊さないことを確認）
2. [ ] `application_helper.rb`: `expand_snapshot_plugin` を追加
3. [ ] `admin/unit_snapshots/index.html.erb` にID列を追加
4. [ ] `admin/units/_snapshots_list.html.erb` にID列を追加
5. [ ] `test/helpers/application_helper_test.rb` 新規作成（include回帰 + snapshot正常系/異常系）
6. [ ] `custom_pages_controller_test.rb` にsnapshot埋め込みのE2Eテスト追加
7. [ ] 手動確認: 実際にCustomPageの `body` に `{{snapshot <key>,<id>}}` を書いて表示崩れがないか確認（特にマクロ前後の空行、htmxの過去メンバー展開）
8. [ ] ブランチ `feat/issue-953-snapshot-embed` を `develop` から作成しPR作成

---

## 影響範囲まとめ

| ファイル | 変更内容 |
|---|---|
| `app/helpers/application_helper.rb` | `expand_include_macros` を汎用プラグインディスパッチ機構にリファクタリング + `expand_snapshot_plugin` 新規追加 |
| `app/views/admin/unit_snapshots/index.html.erb` | ID列を追加 |
| `app/views/admin/units/_snapshots_list.html.erb` | ID列を追加 |
| `test/helpers/application_helper_test.rb` | 新規（プラグイン記法のテスト） |
| `test/controllers/custom_pages_controller_test.rb` | snapshot埋め込みのE2Eテスト追加 |
| `app/models/custom_page.rb` | 変更なし（include固有ロジックはそのまま） |
