// 地図のマーカーのポップアップの中身（issue #1801）。地図ライブラリに依存しない共通の部品で、
// どのアダプター（Leaflet / Google マップ）からも同じものを使う。
// 会場名などは textContent で入れ、HTML として解釈させない（XSS 対策）
export function buildPopupContent(venue) {
  const wrapper = document.createElement("div")
  wrapper.className = "venue-map-popup"

  const link = document.createElement("a")
  link.className = "venue-map-popup__name"
  link.href = venue.url
  link.textContent = venue.name
  wrapper.appendChild(link)

  if (venue.type) {
    const type = document.createElement("div")
    type.className = "venue-map-popup__type"
    type.textContent = venue.type
    wrapper.appendChild(type)
  }

  return wrapper
}
