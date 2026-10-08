# 会場の地図（都道府県ページ・エリアページ）

issue #1801。`/venues/area/:prefecture`（都道府県ページ）と `/venues/area/:prefecture/:area`（エリアページ）に、範囲内の会場を地図と一覧で表示する。

会場ページ（`/venues/:key`）の地図は、これとは別の Google マップの埋め込み（住所で検索、issue #1781）のまま。

## 座標

- `venues.latitude` / `venues.longitude`（世界測地系の10進数の度）と、取得元の `coordinates_source`（`geocoded` = 住所から自動取得 / `manual` = 管理画面で手入力）を持つ
- 自動取得は国土地理院の住所検索 API（`GsiGeocoder`、API キー不要）
  - 会場の作成・住所／都道府県／種別の変更時に `GeocodeVenueJob` で取得する（`VenueGeocodable`）
  - 既存の会場は `bundle exec rails venues:geocode`（座標のない会場だけ）。`FORCE=1` で手入力以外を取り直す
  - 配信の会場・都道府県が「海外」の会場・住所のない会場は取得しない
- 管理画面で緯度・経度を入力すると手入力になり、以後は自動取得で上書きしない。両方を空にして保存すると自動取得に戻る
- 地図にプロットするのは `Venue.kept.mappable`（座標あり・閉店と配信以外）。一覧には範囲内のすべての会場を出す

## 構成（地図ライブラリへの依存を分ける）

後で Google マップに切り替える可能性があるため、地図ライブラリに依存する部分を JavaScript のアダプター1ファイルに閉じ込めている。

| 層 | ファイル | 地図ライブラリへの依存 |
|---|---|---|
| 会場データの組み立て | `app/helpers/venue_map_helper.rb`（`venue_map_data` → `{ name, url, type, lat, lng }` の配列） | なし |
| ビュー | `app/views/venue_areas/show.html.erb`（`data-controller="venue-map"` と data 属性を出すだけ） | なし |
| Stimulus コントローラー | `app/javascript/controllers/venue_map_controller.js`（アダプターを選んで呼ぶ） | なし |
| ポップアップの中身 | `app/javascript/venue_map/popup.js` | なし |
| 外部ファイルの読み込み | `app/javascript/venue_map/asset_loader.js` | なし |
| アダプター | `app/javascript/venue_map/leaflet_adapter.js` | **Leaflet・地理院タイル・markercluster** |
| テスト | `test/controllers/venue_areas_controller_test.rb` など（data 属性の会場データを検証する） | なし |

アダプターは `createMap(element, venues, options)` を export し、`{ destroy() }` を返す（Promise 可）。

- `venues`: `[{ name, url, type, lat, lng }]`
- `options`: `{ maxZoom }`（`VenueMapHelper#venue_map_options`）
- 地図の表示範囲はプロットした会場がすべて収まるように合わせ、会場が多いときはマーカーをまとめる（クラスタリング）
- マーカーをクリックすると `buildPopupContent(venue)`（会場名のリンクと種別）を表示する

### 今のアダプター（Leaflet）が読み込む外部ファイル

| 用途 | ホスト |
|---|---|
| Leaflet 1.9.4・Leaflet.markercluster 1.5.3 のスクリプト・CSS・マーカー画像 | `unpkg.com`（SRI 付き） |
| 地図タイル（地理院タイル 標準地図） | `cyberjapandata.gsi.go.jp` |

地理院タイルは利用規約により出典（「地理院タイル」）を表示する（地図の右下）。

## Google マップに切り替える場合

1. `app/javascript/venue_map/google_adapter.js` を作り、同じ `createMap(element, venues, options)` を実装する
   - Maps JavaScript API の読み込み（API キーが必要）、マーカー、`InfoWindow` に `buildPopupContent(venue)` を渡す、`fitBounds`（`maxZoom` を守る）、`@googlemaps/markerclusterer` でクラスタリング
2. `venue_map_controller.js` の `ADAPTERS` に `google: () => import("venue_map/google_adapter")` を足す
3. `VenueMapHelper::VENUE_MAP_PROVIDER` を `'google'` にする
4. API キーを用意する
   - Google Cloud で Maps JavaScript API を有効にし、課金アカウントを設定する（無料枠を超えると有料）
   - キーは HTTP リファラーで本番ドメインに制限し、credentials か環境変数から読む（コードに書かない）。ビューから data 属性でアダプターに渡す
5. Content Security Policy を設定している場合は `maps.googleapis.com`・`maps.gstatic.com` などを許可する（今は CSP を設定していない）
6. 出典表示は Google マップが自動で出すため、地理院タイルの出典は不要になる

座標は国土地理院の住所検索 API で取得したもの（JGD2011。世界測地系で WGS84 とほぼ同じ）をそのまま Google マップにも置ける。会場データ・ビュー・テストは変えなくてよい。
