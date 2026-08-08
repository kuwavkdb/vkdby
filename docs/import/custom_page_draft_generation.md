# カスタムページ下書き生成（custom_page_drafts）

[issue #1086](https://github.com/kuwavkdb/vkdby/issues/1086)（[issue #929](https://github.com/kuwavkdb/vkdby/issues/929) のサブIssue）で追加した、`page_type=custom_page` に仕訳済みの `Wikipage` から `CustomPage`（Markdown）の下書きをベストエフォートで生成する仕組みについて記述する。

## 前提・運用方針

- 本番DBとローカルDBは分離しており、DBの行データを直接移送することはできない。
- そのためこのタスクは**ローカル環境専用**とする。生成した下書きは、人手で本番の `/admin/custom_pages/new` へコピー＆ペーストして作成・公開する運用を想定している（対象は現状30件程度のため、自動デプロイは行わない）。
- 対象は `WikiPageImport.page_type = 'custom_page'` のみ。`live_house` / `office_label` / `omnibus` は性質が異なる（施設名・レーベル名・オムニバス盤の一覧）ため対象外。

## 実行方法

### 全件生成

```bash
bundle exec rails custom_page_drafts:generate
```

対象は `WikiPageImport.where(page_type: 'custom_page')` 全件。出力先は `tmp/custom_page_drafts/`（`.gitignore` 対象、コミットされない）。

### 特定の1件だけ生成

```bash
WIKIPAGE_ID=8619 bundle exec rails custom_page_drafts:generate
```

`WIKIPAGE_ID` には `wikipages.id`（`WikiPageImport#wikipage_id`）を指定する。

### ローカル管理画面でプレビューする

```bash
PREVIEW=1 bundle exec rails custom_page_drafts:generate
```

ファイル出力に加えて、ローカルDBに `key: "page-<wikipage_id>"` の `CustomPage`（`active: false` の下書き）を作成・更新する。ローカルで起動して `/admin/custom_pages` の編集画面を開けば、Markdownプレビュー付きで見た目を確認できる。`key` を軸に upsert するだけなので、何度再実行しても安全。

### 変換ロジックだけを単体で試す（Rails console）

```ruby
wp = Wikipage.find(8619)
draft = CustomPageDraftGenerator.generate(wp)
draft.key       # 仮キー "page-8619"
draft.title     # wikipage.title.presence || wikipage.name
draft.old_key   # 旧サイトURL用（EUC-JPパーセントエンコード）
draft.body      # 変換後のMarkdown
draft.warnings  # 要手動対応の一覧
```

## 出力ファイルの形式

`tmp/custom_page_drafts/<wikipage_id>_<title>.md` に1ページ1ファイルで出力される。

```markdown
<!--
wikipage_id: 8619
key(仮):      page-8619
title:        運営方針について
old_key:      %B1%BF%B1%C4%CA%FD%BF%CB%A4%CB%A4%C4%A4%A4%A4%C6
warning:      内部リンク [[編集について]] はリンク解決できないため平文化しました（要手動対応）
-->

# 運営方針について
...
```

- `old_key` は Unit/Person importer と同じ規約（`URI.encode_www_form_component(name.encode('EUC-JP'))`）で算出している。[issue #1085](https://github.com/kuwavkdb/vkdby/issues/1085)（旧URLリダイレクト対応）で `custom_pages.old_key` 列が追加され次第、この値をそのまま使える。
- `key(仮)` は自動採番していない（対象ページにはカナ読みがなく、Unit/Personのようなローマ字変換ができないため）。公開時に管理画面で正式な `key` に変更する前提。

## 変換ルール（`CustomPageDraftGenerator`）

実装: [app/services/custom_page_draft_generator.rb](../../app/services/custom_page_draft_generator.rb)

| 元記法（PukiWiki） | 変換後（Markdown） | 備考 |
|---|---|---|
| `//コメント行` | 除去 | |
| `{{b_hidden ...}}` | 除去 | |
| `!!!` / `!!` / `!` | `#` / `##` / `###` | `!` の数が多いほど上位見出し |
| `*` / `**` / `***` | `-` / `  -` / `    -` | 入れ子リスト |
| `[[label\|url]]` / `[label\|url]` | `[label](url)` | `url` が `http(s)://` または `/` で始まる場合のみ |
| `[[label\|target]]`（targetがURLでない） | `label`（平文化）＋警告 | wikiページ名やサービス独自記法（例: `TBTV-Visual:452`）を誤ってリンク化しないため |
| `[[PageName]]` | `[PageName](/key)` または `PageName`（平文化）＋警告 | 同名の `Unit`/`Person` を `kept` スコープで検索し、見つかればプロフィールページへのリンクに自動解決。見つからなければ平文化 |
| `----` | `---` | |
| `{{include ...}}` / `{{snapshot ...}}` | そのまま維持 | `CustomPage` のMarkdownヘルパーが解釈できるプラグインのため変換不要（[docs/custom_page_plugins.md](../custom_page_plugins.md)参照） |
| 上記以外の `{{プラグイン ...}}` | `<!-- TODO: 要手動対応 元記法: {{...}} -->` ＋警告 | `{{tweet}}` `{{a2s}}` `{{category_list_db}}` 等、新サイトに対応機能がないもの |

## 既知の限界

- Amazon商品埋め込み（`{{a2s ASIN}}`）は現時点では変換できず、TODOコメントとして残るのみ。[issue #1087](https://github.com/kuwavkdb/vkdby/issues/1087)（Item card埋め込みプラグイン）が実装されれば `{{item ASIN}}` 等への置き換えが可能になる見込み。
- `{{category_list_db ...}}` のような動的一覧プラグインは、そもそも静的なMarkdownページでは同じ機能を再現できない。該当ページ（例: `events`）は個別に「簡易化して残すか」「対応を見送るか」を人手で判断する必要がある。
- 単一ブラケット `[label|url]` は実データ上すべてURL/相対パスだったため常にリンク化している。今後想定外のデータが出てきた場合は要調整。

## 関連ファイル

| 種別 | ファイル |
|---|---|
| 変換ロジック | [app/services/custom_page_draft_generator.rb](../../app/services/custom_page_draft_generator.rb) |
| rakeタスク | [lib/tasks/custom_page_drafts.rake](../../lib/tasks/custom_page_drafts.rake) |
| テスト | [test/services/custom_page_draft_generator_test.rb](../../test/services/custom_page_draft_generator_test.rb) |
