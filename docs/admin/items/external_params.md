# Admin Items — 外部アプリからのパラメータ渡し仕様

## 概要

`/admin/items/new` は、外部アプリケーションから GET パラメータを渡すことでフォームの初期値を設定できます。
外部の CD データベースや Amazon 商品ページから半自動的に Item を登録する用途を想定しています。

---

## 受け付けるパラメータ

| パラメータ名 | 型 | 対応フィールド | 備考 |
|---|---|---|---|
| `title` | string | タイトル | |
| `release_date` | string | 発売日 | `YYYY-MM-DD` 形式 |
| `link_url` | string | Link URL | |
| `asin` | string | ASIN | |
| `image_url` | string | Image URL | |
| `artist_name` | string | Artists（name） | 1件のみ。空の場合は無視 |
| `artist_key` | string | Artists（key） | `artist_name` がある場合のみ有効 |
| `artist_old_key` | string | Artists（old_key） | `artist_name` がある場合のみ有効。保存時には除外される |

### 注意事項

- `artist_name` を渡すと、Artists フィールドに 1 件の選択済みエントリとして初期表示されます。
- Artists は 1 件のみ渡せます。複数のアーティストは登録画面で手動追加してください。
- `artist_key` / `artist_old_key` は任意です。省略した場合は name のみが設定されます。
- `artist_old_key` はレガシー識別子です。フォーム上には表示されますが、保存時には artists JSON に含まれません。
- 全パラメータが任意です。省略したフィールドは空のまま表示されます。

---

## URL 例

```
/admin/items/new?title=Example+Album&release_date=2025-03-26&asin=B0CXXX&artist_name=Example+Unit&artist_key=example-unit
```

---

## 実装箇所

- **コントローラー**: `app/controllers/admin/items_controller.rb` — `new` アクション
- **フォーム**: `app/views/admin/items/_form.html.erb` — Artists セクション（`artist-rows` Stimulus コントローラー）

```ruby
# new アクション
@item = Item.new(
  title: params[:title],
  release_date: params[:release_date],
  link_url: params[:link_url],
  asin: params[:asin],
  image_url: params[:image_url]
)
@item.artists = build_artist_from_params

# build_artist_from_params
def build_artist_from_params
  return [] if params[:artist_name].blank?
  [{ 'name' => params[:artist_name], 'key' => params[:artist_key], 'old_key' => params[:artist_old_key] }.compact_blank]
end
```
