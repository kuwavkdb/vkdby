// 地図アダプター: Leaflet + 国土地理院タイル（issue #1801）。
// Leaflet に依存するコードはこのファイルだけに置く。Google マップに切り替えるときは、同じ
// createMap(element, venues, options) を持つ google_adapter.js を作り、venue_map_controller.js の
// ADAPTERS に登録して、VenueMapHelper::VENUE_MAP_PROVIDER を変える（docs/venue_map.md）。
//
// 外部から読み込むもの（CSP を設定する場合に許可が必要なホスト）
// - スクリプト・スタイル・マーカー画像: unpkg.com
// - 地図タイル: cyberjapandata.gsi.go.jp
import { loadScript, loadStylesheet } from "venue_map/asset_loader"
import { buildPopupContent } from "venue_map/popup"

const LEAFLET_URL = "https://unpkg.com/leaflet@1.9.4/dist"

const STYLESHEET = { href: `${LEAFLET_URL}/leaflet.css`, integrity: "sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" }
const SCRIPT = { src: `${LEAFLET_URL}/leaflet.js`, integrity: "sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" }

// 地理院タイル（標準地図）。利用規約により出典を表示する
const TILE_LAYER = {
  url: "https://cyberjapandata.gsi.go.jp/xyz/std/{z}/{x}/{y}.png",
  attribution: '<a href="https://maps.gsi.go.jp/development/ichiran.html" target="_blank" rel="noopener">地理院タイル</a>',
  minZoom: 5,
  maxZoom: 18
}

async function loadLeaflet() {
  await Promise.all([loadStylesheet(STYLESHEET), loadScript(SCRIPT)])
  const L = window.L
  // CDN の CSS から画像のパスを推測させず、明示する
  L.Icon.Default.imagePath = `${LEAFLET_URL}/images/`
  return L
}

// venues: [{ name, url, type, lat, lng }]、options: { maxZoom }。戻り値の destroy() で地図を片付ける
export async function createMap(element, venues, options = {}) {
  const L = await loadLeaflet()

  const map = L.map(element, {
    // ページのスクロール中に地図が拡大縮小・移動しないようにする。スマホは1本指のドラッグで地図を動かさない
    scrollWheelZoom: false,
    dragging: !L.Browser.mobile
  })
  L.tileLayer(TILE_LAYER.url, {
    attribution: TILE_LAYER.attribution,
    minZoom: TILE_LAYER.minZoom,
    maxZoom: TILE_LAYER.maxZoom
  }).addTo(map)

  // マーカーはまとめず（クラスタリングせず）、会場ごとに1本ずつ立てる
  const markers = L.featureGroup()
  venues.forEach((venue) => {
    const marker = L.marker([venue.lat, venue.lng], { title: venue.name, alt: venue.name, keyboard: true })
    marker.bindPopup(() => buildPopupContent(venue))
    markers.addLayer(marker)
  })
  markers.addTo(map)
  map.fitBounds(markers.getBounds(), { padding: [24, 24], maxZoom: options.maxZoom || TILE_LAYER.maxZoom })

  return {
    destroy() {
      map.remove()
    }
  }
}
