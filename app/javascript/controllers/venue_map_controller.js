import { Controller } from "@hotwired/stimulus"

// 都道府県・エリアページの会場の地図（issue #1801）。
// ビューは会場データ（JSON）と使うアダプター名を data 属性で渡すだけにし、地図ライブラリを扱うのは
// アダプター（app/javascript/venue_map/*_adapter.js）に任せる。アダプターは
// createMap(element, venues, options) を持ち、{ destroy() } を返す。
// Google マップに切り替えるときは google_adapter.js を作ってここに登録する（docs/venue_map.md）
const ADAPTERS = {
  leaflet: () => import("venue_map/leaflet_adapter")
}

export default class extends Controller {
  static targets = ["canvas", "error"]
  static values = {
    provider: { type: String, default: "leaflet" },
    venues: Array,
    options: Object
  }

  async connect() {
    this.connected = true
    // Turbo のキャッシュから復元したときに残っている前回の地図の DOM を消す
    this.canvasTarget.replaceChildren()

    const loadAdapter = ADAPTERS[this.providerValue]
    if (!loadAdapter || this.venuesValue.length === 0) return

    try {
      const adapter = await loadAdapter()
      const map = await adapter.createMap(this.canvasTarget, this.venuesValue, this.optionsValue)
      if (this.connected) {
        this.map = map
      } else {
        map.destroy()
      }
    } catch (error) {
      console.error(error)
      if (this.connected && this.hasErrorTarget) this.errorTarget.hidden = false
    }
  }

  disconnect() {
    this.connected = false
    this.map?.destroy()
    this.map = null
  }
}
