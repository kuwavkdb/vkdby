# カスタムページ プラグイン記法 仕様

CustomPage の `body`（Markdown）内に `{{プラグイン名 パラメータ}}` の形式で書くと、Markdown解析前に専用の処理へディスパッチされ、結果が本文に展開される仕組み。[issue #955](https://github.com/kuwavkdb/vkdby/issues/955)（汎用化）・[issue #953](https://github.com/kuwavkdb/vkdby/issues/953)（`snapshot` プラグイン追加）で整備した。

対象は `markdown(text, sectionable:)` ヘルパー（[app/helpers/application_helper.rb](../app/helpers/application_helper.rb)）を経由するすべての描画箇所。現状の呼び出し元は [app/views/custom_pages/show.html.erb:24](../app/views/custom_pages/show.html.erb#L24) のみ（`markdown(@page.body, sectionable: @page)`）。

---

## 記法

```
{{プラグイン名 パラメータ}}
```

- プラグイン名は `\w[\w-]*`（英数字・アンダースコア・ハイフン、先頭は英数字またはアンダースコア）にマッチする必要がある
- プラグイン名とパラメータの間は空白（1文字以上）区切り
- パラメータ部分は non-greedy マッチで、最初に現れる `}}` までを1つのマクロとして扱う
- 未登録のプラグイン名（例: `{{foo bar}}`）は**マッチした文字列をそのまま残す**（意図しない消失を防ぐため）

解析の実体は `ApplicationHelper#expand_plugin_macros` の正規表現 `/\{\{(\w[\w-]*)\s+(.+?)\}\}/m`。

```ruby
PLUGIN_HANDLERS = {
  'include' => :expand_include_plugin,
  'snapshot' => :expand_snapshot_plugin,
  'item' => :expand_item_plugin
}.freeze
```

---

## 処理の全体フロー（`markdown` ヘルパー）

1. `expand_plugin_macros` で本文中の `{{...}}` を走査し、登録済みプラグインなら対応ハンドラーを呼び出す
2. ハンドラーの返り値で本文中のマクロ部分を置換する
3. 置換後の本文全体を Redcarpet でMarkdown→HTMLに変換する
4. プレースホルダー（後述）が残っていれば、実際のHTMLに復元する

```ruby
def markdown(text, sectionable: nil)
  return '' if text.blank?

  placeholders = {}
  text = expand_plugin_macros(text, sectionable:, placeholders:)

  renderer = ExternalAwareHtmlRenderer.new(site_host: request.host, hard_wrap: true)
  html = Redcarpet::Markdown.new(renderer, ...).render(text)
  restore_plugin_placeholders(html, placeholders).html_safe
end
```

各ハンドラーは `handler(args, sectionable, placeholders)` というシグネチャで呼ばれる（`args` はプラグイン名の後の文字列、`sectionable` は `markdown` 呼び出し元から渡された `Section` の親レコード、`placeholders` はプレースホルダー登録用のハッシュ）。

---

## `include` プラグイン

既存の `Section`（`app/models/section.rb`）の本文を差し込む。**Markdown本文としてそのまま Redcarpet に再解析させる**（後述の `snapshot` とは方式が異なる点に注意）。

| 記法 | 参照先 |
|---|---|
| `{{include key,セクション名}}` | `CustomPage`（`key` で published のページを検索） |
| `{{include unit:ID,セクション名}}` | `Unit`（`id` で検索） |
| `{{include person:ID,セクション名}}` | `Person`（`id` で検索） |
| `{{include ,セクション名}}` | 自身のページ（`sectionable` 引数、カンマあり・識別子省略） |
| `{{include セクション名}}` | 自身のページ（`sectionable` 引数、カンマなし） |

- パラメータはカンマの有無で `identifier, section_name` を分解する（`args.split(',', 2)`。最初のカンマのみで分割するため、セクション名自体にカンマが含まれていても壊れない）
- 対象レコードの `sections.kept`（discard されていない）から `name: section_name` に一致するものを検索
- 本文は `section.markdown.presence || section.wiki_text.presence || ''`（`markdown` フィールド優先、なければ `wiki_text`、どちらもなければ空文字）
- 見つからない場合（`key`/`ID` 誤り、セクション名不一致等）は**空文字を返す（サイレント失敗）**

### `CustomPage` 側の循環参照チェック（`include` 専用・変更なし）

`app/models/custom_page.rb` は `{{include key,セクション名}}` 専用の正規表現（`\{\{include\s+([a-z0-9_-]+),(.+?)\}\}`）で `body` を独自にスキャンし、以下を行う（`ApplicationHelper` の汎用化とは無関係の別ロジック）。

- `rebuild_include_relations`: `CustomPageInclude` 中間テーブルへ include 関係を記録（`body` 保存時）
- `no_circular_includes`: A→B→A のような循環 include を検出してバリデーションエラーにする

この仕組みは `include` 固有であり、`snapshot` など他のプラグインには適用されない（ページ間参照ではないため対象外）。

---

## `snapshot` プラグイン

指定したバンド（`Unit`）の特定のラインアップスナップショット（`UnitSnapshot`）を埋め込む。

**記法:** `{{snapshot ユニットkey,snapshot_id}}`

```ruby
def expand_snapshot_plugin(args, _sectionable, placeholders)
  unit_key, snapshot_id = args.split(',', 2).map(&:strip)
  return '' if unit_key.blank? || snapshot_id.blank?

  unit = Unit.kept.find_by(key: unit_key)
  snapshot = unit&.unit_snapshots&.active&.find_by(id: snapshot_id)
  return '' unless snapshot

  html = render(UnitSnapshotsComponent.new(snapshots: [snapshot], unit: unit, admin: false, show_label: false)).to_s
  register_plugin_placeholder(placeholders, html)
end
```

- `Unit.kept`（discard されていない）を `key` で検索
- 見つかった Unit の `unit_snapshots.active`（**公開スコープのみ**。プロフィールページの公開表示と同じ範囲）から `id: snapshot_id` を検索
  - これにより「指定バンド以外の snapshot_id を誤って参照できない」「非公開スナップショットは埋め込めない」の2点を保証する
- 見つからない場合（`key` 誤り、`snapshot_id` 誤り、別ユニットの ID、非公開等）は**空文字を返す（サイレント失敗、`include` と同じ方針）**
- 描画は既存の `UnitSnapshotsComponent`（バンドプロフィールページと共通）を `snapshots: [snapshot]` として再利用
  - `show_label: false` を渡し、バンドページと異なりラベルバッジ（「結成時」等）は非表示にする（[app/components/unit_snapshots_component.rb](../app/components/unit_snapshots_component.rb)）
- `snapshot_id` の確認は管理画面のスナップショット一覧（`admin/unit_snapshots#index` および Unit編集画面内の一覧）にID列を表示済み（[issue #954](https://github.com/kuwavkdb/vkdby/issues/954)）

---

## `item` プラグイン

指定したASINの商品（`Item`）カードを埋め込む。旧サイトの `{{a2s ASIN[,ASIN...]}}`（Amazon商品埋め込み）記法からの移行先（[issue #1087](https://github.com/kuwavkdb/vkdby/issues/1087)）。まずは単一ASINのみに対応し、複数ASIN対応は必要になった時点で別途拡張する。

**記法:** `{{item ASIN}}`

```ruby
def expand_item_plugin(args, _sectionable, placeholders)
  asin = args.strip
  return '' if asin.blank?

  item = Item.find_by(asin: asin)
  return '' unless item

  html = render(ItemCardComponent.new(item_card: item)).to_s
  register_plugin_placeholder(placeholders, html)
end
```

- `Item#asin`（一意）で検索する
- 見つからない場合（ASIN未登録・誤り等）は**空文字を返す（サイレント失敗、`include`/`snapshot` と同じ方針）**
- 描画は既存の `ItemCardComponent`（商品ページ・関連作品グリッド等と共通）を再利用する
- `ItemCardComponent` が生成するHTMLはStimulus属性（`data-controller="item-card-artists"`）を含む複数行タグのため、`snapshot` と同じ**プレースホルダー方式**を使う（`include` 方式だとRedcarpetの生HTML解析でタグが壊れる。詳細は次節参照）

### なぜプレースホルダー方式にしているか

`UnitSnapshotsComponent` が生成するHTMLは、Stimulus (`data-controller`, `data-action`) や htmx (`hx-get`, `hx-trigger`) の属性を持つ複数行の `<div ...>` タグを含む。これを `include` と同じ方式（文字列としてMarkdown本文に差し込み、Redcarpetで再解析させる）で実装したところ、以下の問題が手動確認で見つかった。

- Redcarpet の生HTMLブロック認識が、属性が複数行にまたがるタグを正しく扱えず、タグの属性がテキストとして画面に露出してしまう
- 開発環境の `annotate_rendered_view_with_filenames`（`config/environments/development.rb`）が挿入する `<!-- BEGIN ... -->` / `<!-- END ... -->` コメントも同様に本文へ混入し、解析を乱す一因になる

対応として、コンポーネントの描画結果を本文に直接差し込まず、一意なプレースホルダートークン（`⟦PLUGIN_PLACEHOLDER_xxxxxxxx⟧`）に置き換えて差し込み、**Redcarpetによる本文全体のレンダリングが完了した後**にトークンを実際のレンダリング結果へ復元する方式にした（`register_plugin_placeholder` / `restore_plugin_placeholders`）。これにより、コンポーネントHTMLはMarkdownパーサーを一切経由せず、最終レンダリング結果としてそのまま出力される。

```ruby
def register_plugin_placeholder(placeholders, html)
  token = "⟦PLUGIN_PLACEHOLDER_#{SecureRandom.hex(8)}⟧"
  placeholders[token] = html
  token
end

def restore_plugin_placeholders(html, placeholders)
  placeholders.each do |token, raw_html|
    html = html.sub("<p>#{token}</p>", raw_html)  # ブロック要素として単独行に書かれた場合
    html = html.sub(token, raw_html)               # 上記でマッチしなかった場合のフォールバック
  end
  html
end
```

**注意点:** マクロを単独の行として書き、前後に空行を入れること（Markdownの段落認識ルール上、そうしないと `<p>token</p>` の形にならず、周辺のテキストと同じ段落内にトークンが埋め込まれてしまい、`restore_plugin_placeholders` のブロック単位置換が効かない）。

```markdown
本文の説明文。

{{snapshot ayabie,38288}}

続きの本文。
```

---

## 新しいプラグインを追加する場合

1. `ApplicationHelper` に `expand_〇〇_plugin(args, sectionable, placeholders)` を実装する
2. `PLUGIN_HANDLERS` にプラグイン名とメソッド名（シンボル）を登録する
3. 返す内容がプレーンなMarkdown/テキスト（Redcarpetに再解析させてよいもの）であれば、そのまま文字列を返す（`include` 方式）
4. 返す内容が既にレンダリング済みのHTML（Stimulus/htmx等の複雑な属性を含むコンポーネント出力等）であれば、`register_plugin_placeholder(placeholders, html)` の返り値（トークン文字列）を返す（`snapshot` 方式）
5. 対象が見つからない・パラメータ不正等の異常系は空文字を返す（サイレント失敗。ユーザー向けにエラー表示はしない、既存プラグインとの一貫性を優先）

---

## 実装箇所

| 種別 | ファイル |
|---|---|
| ディスパッチ機構・`include`・`snapshot`・`item` | [app/helpers/application_helper.rb](../app/helpers/application_helper.rb) |
| `include` 専用の循環参照チェック（別ロジック） | [app/models/custom_page.rb](../app/models/custom_page.rb) |
| `snapshot` の描画コンポーネント | [app/components/unit_snapshots_component.rb](../app/components/unit_snapshots_component.rb), [app/components/unit_snapshots_component.html.erb](../app/components/unit_snapshots_component.html.erb) |
| `item` の描画コンポーネント | [app/components/item_card_component.rb](../app/components/item_card_component.rb), [app/components/item_card_component.html.erb](../app/components/item_card_component.html.erb) |
| 管理画面（スナップショットID確認用） | [app/views/admin/unit_snapshots/index.html.erb](../app/views/admin/unit_snapshots/index.html.erb), [app/views/admin/units/_snapshots_list.html.erb](../app/views/admin/units/_snapshots_list.html.erb) |
| テスト | [test/helpers/application_helper_test.rb](../test/helpers/application_helper_test.rb), [test/controllers/custom_pages_controller_test.rb](../test/controllers/custom_pages_controller_test.rb) |

## 権限について

`CustomPage#body` の編集権限自体は本機能追加による変更なし（`Admin::BaseController` の `require_login` のみが効き、operator 以上の全ログインユーザーが編集可能）。`docs/admin/permissions.md` の更新は不要と判断した（[issue #957](https://github.com/kuwavkdb/vkdby/issues/957) で確認済み）。
