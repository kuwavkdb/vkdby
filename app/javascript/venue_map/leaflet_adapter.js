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
const MARKERCLUSTER_URL = "https://unpkg.com/leaflet.markercluster@1.5.3/dist"

const STYLESHEETS = [
  { href: `${LEAFLET_URL}/leaflet.css`, integrity: "sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" },
  { href: `${MARKERCLUSTER_URL}/MarkerCluster.css`, integrity: "sha256-YU3qCpj/P06tdPBJGPax0bm6Q1wltfwjsho5TR4+TYc=" },
  { href: `${MARKERCLUSTER_URL}/MarkerCluster.Default.css`, integrity: "sha256-YSWCMtmNZNwqex4CEw1nQhvFub2lmU7vcCKP+XVwwXA=" }
]

// markercluster は Leaflet（window.L）を前提にするため、この順に読み込む
const SCRIPTS = [
  { src: `${LEAFLET_URL}/leaflet.js`, integrity: "sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" },
  { src: `${MARKERCLUSTER_URL}/leaflet.markercluster.js`, integrity: "sha256-Hk4dIpcqOSb0hZjgyvFOP+cEmDXUKKNE/tT542ZbNQg=" }
]

// 地理院タイル（標準地図）。利用規約により出典を表示する
const TILE_LAYER = {
  url: "https://cyberjapandata.gsi.go.jp/xyz/std/{z}/{x}/{y}.png",
  attribution: '<a href="https://maps.gsi.go.jp/development/ichiran.html" target="_blank" rel="noopener">地理院タイル</a>',
  minZoom: 5,
  maxZoom: 18
}

async function loadLeaflet() {
  await Promise.all(STYLESHEETS.map(loadStylesheet))
  for (const script of SCRIPTS) await loadScript(script)
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

  // 会場の多い都道府県ページのため、ズームアウト時はマーカーをまとめる
  const markers = L.markerClusterGroup({ showCoverageOnHover: false, maxClusterRadius: 40 })
  venues.forEach((venue) => {
    const marker = L.marker([venue.lat, venue.lng], { title: venue.name, alt: venue.name, keyboard: true })
    marker.bindPopup(() => buildPopupContent(venue))
    markers.addLayer(marker)
  })
  map.addLayer(markers)
  map.fitBounds(markers.getBounds(), { padding: [24, 24], maxZoom: options.maxZoom || TILE_LAYER.maxZoom })

  return {
    destroy() {
      map.remove()
    }
  }
}
