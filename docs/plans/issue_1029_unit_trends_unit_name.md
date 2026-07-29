# Issue #1029: Unitページ内のTrends改善 実装プラン

## Issue概要
- Unitページ内のTrends一覧は、実際の表記（当時の名前）が現在の表示と異なっていてもユニット名が表示されず、区別がつかない。
- 対応方針（ユーザーと相談の上で決定）: **現在表示中のUnitページの名前と異なる場合のみ**、当時のユニット名をバッジ表示する。
  - 一致する場合（大半のケース）はバッジを出さず一覧を煩雑にしない。
  - 改名前の表記で記録されたtrendは当時の名前が表示され、気づける。
  - 複数ユニットが絡むtrend（合流・関連ユニットなど）は、自ユニット以外のunit_idは無条件で「異なる」ため常にバッジ表示される。
  - エイリアス一致かどうかは特別扱いしない。現在の主表記（`name`）と完全一致するかどうかだけで判定する（エイリアス経由の表記もissueの問題意識通り「表記差」として見せる）。

## 現状の実装（調査結果）
- Unitページのtrend一覧は [profiles/show.html.erb:77](../../app/views/profiles/show.html.erb#L77) の `render UnitTrendsComponent.new(trends: @trends)` → [unit_trends_component.html.erb](../../app/components/unit_trends_component.html.erb) → [trend_list_row_component.html.erb](../../app/components/trend_list_row_component.html.erb) が描画を担う。現状は日付とタイトルのみで、trendに紐づくユニット名は一切表示していない。
- `TrendListRowComponent` / `UnitTrendsComponent` はどちらも `trend:` しか受け取らず、「今どのUnitページを見ているか」というコンテキストを持っていない（[trend_list_row_component.rb:9](../../app/components/trend_list_row_component.rb#L9)、[unit_trends_component.rb:7](../../app/components/unit_trends_component.rb#L7)）。
- 一方、trend詳細ページ（[trends/show.html.erb:20-31](../../app/views/trends/show.html.erb#L20-L31)）ではすでに同種のバッジ表示ロジックがある。`Trend#units`（jsonb、`unit_id` と当時の `name` を保持）を1件ずつ [trends_helper.rb:6](../../app/helpers/trends_helper.rb#L6) の `trend_unit_display_name(unit_data, unit)` に通し、「当時のnameを優先、無ければ現在のUnit名にフォールバック」した表示名を算出している。今回はこのヘルパーをそのまま再利用する。
- `key` はjsonbに保存されていない。実データを確認したところ (`Trend.where.not(units: nil).order(id: :desc).limit(5).pluck(:id, :units)`)、保存されているのは `unit_id` と `name` のみで、`name` や `unit_id` 自体が欠けているレコードも存在する（自由入力名のみ、など）。そのため当時の表記と現在名の比較は `name` 文字列で行うしかなく、リンクを張るには別途 `Unit` を引く必要がある。
- [profiles_controller.rb:86-91](../../app/controllers/profiles_controller.rb#L86-L91) の `load_unit_data` は `@trends` を素の `Trend.where(...)` で取得しており `units` 列は既にロードされている（`select` で絞っていない）ので、Unitページ側は追加のカラム指定は不要。
- [trends_controller.rb:61-63](../../app/controllers/trends_controller.rb#L61-L63) の `@unit_trends`（trend詳細ページ内「同ユニットの他trend」サイドバー、[trends/show.html.erb:108](../../app/views/trends/show.html.erb#L108) で同じ `UnitTrendsComponent` を使用）は `.select(:id, :date, :title)` としており `units` 列を読んでいない。ここは同じコンポーネントを使う以上、同じ改善が及ぶべきなので `:units` の追加が必要。
- discardされたUnitの名前が漏れないことは既存テスト（[trends_controller_test.rb:6-16](../../test/controllers/trends_controller_test.rb#L6-L16)）で保証されている。`Unit.kept` で related units を引く限り、discard済みunitはヒットせず `unit_data['name']` も通常保存されていないため、この保証は今回の変更でも自然に維持される（後述）。
- Personページのtrend一覧（[profiles/show.html.erb:154](../../app/views/profiles/show.html.erb#L154)）も同じ `UnitTrendsComponent` を使っているが、issueはUnitページ限定のスコープのため、明示的に対象外とする（`resource:` を渡さないことで動作を変えない）。

## 未確定事項（着手前に確認したい点）
1. バッジをUnitへのリンクにするか、単なるテキストにするか → trend詳細ページの既存パターン（解決できればリンク、できなければテキストのみのバッジ）を踏襲する前提で進める。そのため `related_units`（`unit_id => Unit` のプリロード）をコントローラー側で用意し、N+1を避ける。
2. バッジのスタイル（サイズ・位置）→ 既存の日付・タイトル2カラムレイアウトを崩さないよう、タイトル上に小さいpill群として追加する前提。具体的なクラスは実装時に既存トーン（slate系グレー、indigoホバー）に合わせる。
3. 新規リンク要素の focus 状態 → CLAUDE.mdのアクセシビリティ要件に従い、新規に追加するバッジリンクには `focus-visible:ring-2` 等を付与する（既存の周辺リンクには focus スタイルが無いが、それらへの遡及対応は本issueのスコープ外とする）。

---

## 1. `TrendsHelper` はそのまま再利用（変更なし）

[trends_helper.rb:6](../../app/helpers/trends_helper.rb#L6) の `trend_unit_display_name(unit_data, unit)` を `TrendListRowComponent` から呼べるよう `include TrendsHelper` を追加するのみ。ロジック自体は変更不要。

---

## 2. `TrendListRowComponent` の拡張

[trend_list_row_component.rb](../../app/components/trend_list_row_component.rb)

```ruby
class TrendListRowComponent < ViewComponent::Base
  include WikiLinkHelper
  include TrendsHelper
  include Rails.application.routes.url_helpers

  with_collection_parameter :trend

  def initialize(trend:, current: false, resource: nil, related_units: {})
    super()
    @trend         = trend
    @current       = current
    @resource      = resource
    @related_units = related_units
  end

  def current? = @current

  # resource（現在表示中のUnit）と表記が異なるユニットのみバッジ表示対象にする
  def unit_badges
    return [] if @resource.nil? || @trend.units.blank?

    @trend.units.filter_map do |unit_data|
      unit = @related_units[unit_data['unit_id']]
      display_name = trend_unit_display_name(unit_data, unit)
      next if display_name.blank?
      next if same_as_current_resource?(unit_data, display_name)

      { name: display_name, unit: unit }
    end
  end

  private

  def same_as_current_resource?(unit_data, display_name)
    return false unless @resource.is_a?(Unit) && unit_data['unit_id'] == @resource.id

    display_name == @resource.name
  end
end
```

- `@resource` が `nil`（Personページの呼び出しなど）の場合は従来通り何も表示しない＝挙動を変えない。
- discardされたunitは `related_units`（`Unit.kept` で構築、後述）に含まれないため `unit` は `nil` になり、`trend_unit_display_name` は `unit_data['name']` のみを見る。既存データでは discard 済みunitの `name` は保存されていないケースが実態なので、通常は `display_name` が blank になりバッジごと出ない（＝既存テストが期待する「discard済みunit名を漏らさない」を維持）。

### テンプレート [trend_list_row_component.html.erb](../../app/components/trend_list_row_component.html.erb)

`current?` / 通常リンクの両分岐の `<p class="font-bold ...">` の直前に、バッジ行を追加する:

```erb
<% if unit_badges.any? %>
  <div class="flex flex-wrap gap-1 mb-1">
    <% unit_badges.each do |badge| %>
      <% if badge[:unit] %>
        <%= link_to badge[:name], profile_path(badge[:unit].key),
            class: "px-1.5 py-0.5 rounded text-[11px] font-bold bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:text-indigo-600 dark:hover:text-indigo-400 focus-visible:outline focus-visible:outline-2 focus-visible:outline-indigo-500 transition-colors" %>
      <% else %>
        <span class="px-1.5 py-0.5 rounded text-[11px] font-bold bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400"><%= badge[:name] %></span>
      <% end %>
    <% end %>
  </div>
<% end %>
```

（`current?` 分岐は既にグレーアウト表示なので、リンクにはせずテキストのみ表示にする軽微な差異は許容する。）

---

## 3. `UnitTrendsComponent` の拡張

[unit_trends_component.rb](../../app/components/unit_trends_component.rb) に `resource:` / `related_units:` を追加し、[unit_trends_component.html.erb:8](../../app/components/unit_trends_component.html.erb#L8) の `TrendListRowComponent.new` 呼び出しに橋渡しする。

```ruby
def initialize(trends:, current_trend_id: nil, top_spacing: true, resource: nil, related_units: {})
  super()
  @trends           = trends
  @current_trend_id = current_trend_id
  @top_spacing      = top_spacing
  @resource         = resource
  @related_units    = related_units
end
```

```erb
<%= render TrendListRowComponent.new(trend: trend, current: current?(trend), resource: @resource, related_units: @related_units) %>
```

---

## 4. コントローラー側: related_units のプリロード

### [profiles_controller.rb:86-91](../../app/controllers/profiles_controller.rb#L86-L91) `load_unit_data`

```ruby
def load_unit_data
  @history = @resource.unit_logs.select(:id, :log_date, :phenomenon, :phenomenon_alias, :text)

  @trends = Trend.where('units @> ?', [{ unit_id: @resource.id }].to_json)
                 .order(date: :desc)
                 .limit(10)

  trend_unit_ids = @trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
  @trend_related_units = Unit.kept.where(id: trend_unit_ids).index_by(&:id)

  @snapshots = ...
  # (以下変更なし)
end
```

### [trends_controller.rb:61-63](../../app/controllers/trends_controller.rb#L61-L63) `show`

`units` 列を `select` に追加し、related units を新たにプリロードする:

```ruby
@unit_trends = Trend.where('units @> ?', [{ unit_id: unit.id }].to_json)
                    .select(:id, :date, :title, :units)
                    .order(date: :asc)

unit_trend_unit_ids = @unit_trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
@unit_trends_related_units = Unit.kept.where(id: unit_trend_unit_ids).index_by(&:id)
```

---

## 5. ビュー側の呼び出し変更

### [profiles/show.html.erb:77](../../app/views/profiles/show.html.erb#L77)（Unitページ本体、変更対象）

```erb
<%= render UnitTrendsComponent.new(trends: @trends, resource: @resource, related_units: @trend_related_units) %>
```

### [profiles/show.html.erb:154](../../app/views/profiles/show.html.erb#L154)（Personページ、変更なし）

`resource:` を渡さないままにし、挙動を変えない（issueのスコープ外）。

### [trends/show.html.erb:108](../../app/views/trends/show.html.erb#L108)（trend詳細ページのサイドバー、変更対象）

```erb
<%= render UnitTrendsComponent.new(trends: @unit_trends, current_trend_id: @trend.id, top_spacing: false, resource: @unit, related_units: @unit_trends_related_units) %>
```

---

## 6. テスト

[trends_controller_test.rb](../../test/controllers/trends_controller_test.rb) の既存パターン（`Unit.create!` → `Trend.create!(units: [...])` → `get` → `assert_includes/not_includes`）に倣う。

- `test/controllers/profiles_controller_test.rb` に追加:
  - 現在名と異なる当時の名前を持つtrendを表示すると、当時の名前バッジが表示されること。
  - trendの当時の名前が現在のUnit名と一致する場合、バッジが表示されないこと（一覧が煩雑にならない確認）。
  - 他ユニット（合流relatedなど）を含むtrendの場合、そのユニット名が常にバッジ表示され、`profile_path` へのリンクになっていること。
  - discardされたユニットを参照するtrendでバッジ経由で名前が漏れないこと（既存のdiscard保護方針の踏襲確認）。
- `test/controllers/trends_controller_test.rb` に追加:
  - trend詳細ページのサイドバー（`@unit_trends`）でも同様に、当時名が異なる場合のみバッジが出ることを確認する1件。

---

## 7. ドキュメント更新

- `docs/admin/permissions.md`: 管理画面の新機能・権限変更ではないため更新不要。

---

## 実装順序（チェックリスト）

1. [ ] `app/helpers/trends_helper.rb` は変更なしで確認のみ
2. [ ] `app/components/trend_list_row_component.rb`: `resource:` / `related_units:` 追加、`unit_badges` 実装
3. [ ] `app/components/trend_list_row_component.html.erb`: バッジ表示を追加
4. [ ] `app/components/unit_trends_component.rb` / `.html.erb`: `resource:` / `related_units:` の橋渡し
5. [ ] `app/controllers/profiles_controller.rb`: `load_unit_data` に `@trend_related_units` プリロード追加
6. [ ] `app/controllers/trends_controller.rb`: `@unit_trends` の `select` に `:units` 追加、`@unit_trends_related_units` プリロード追加
7. [ ] `app/views/profiles/show.html.erb:77`: `resource:` / `related_units:` を渡す（154行目のPerson側は変更しない）
8. [ ] `app/views/trends/show.html.erb:108`: `resource:` / `related_units:` を渡す
9. [ ] `test/controllers/profiles_controller_test.rb` にテスト追加
10. [ ] `test/controllers/trends_controller_test.rb` にテスト追加
11. [ ] 手動確認: 実際に改名済みUnit・合流relatedを持つUnitのページで表示崩れがないか、ダーク/ライト両モードで確認
12. [ ] ブランチ `feat/issue-1029-unit-trends-name-badge` を `develop` から作成しPR作成

---

## 影響範囲まとめ

| ファイル | 変更内容 |
|---|---|
| `app/components/trend_list_row_component.rb` | `resource:` / `related_units:` 追加、`unit_badges` メソッド新規 |
| `app/components/trend_list_row_component.html.erb` | 当時のユニット名バッジ表示を追加 |
| `app/components/unit_trends_component.rb` | `resource:` / `related_units:` を追加し `TrendListRowComponent` に橋渡し |
| `app/components/unit_trends_component.html.erb` | `TrendListRowComponent.new` 呼び出しに `resource:` / `related_units:` を追加 |
| `app/controllers/profiles_controller.rb` | `load_unit_data` に `@trend_related_units` プリロード追加 |
| `app/controllers/trends_controller.rb` | `@unit_trends` の `select` に `:units` 追加、`@unit_trends_related_units` プリロード追加 |
| `app/views/profiles/show.html.erb` | Unitページ（77行目）の呼び出しに `resource:` / `related_units:` を追加。Personページ（154行目）は変更なし |
| `app/views/trends/show.html.erb` | サイドバー（108行目）の呼び出しに `resource:` / `related_units:` を追加 |
| `test/controllers/profiles_controller_test.rb` | バッジ表示・非表示・discard保護のテスト追加 |
| `test/controllers/trends_controller_test.rb` | サイドバーでのバッジ表示テスト追加 |
