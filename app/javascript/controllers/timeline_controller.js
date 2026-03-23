import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header", "body", "tooltip", "legendContainer", "markerLegend", "toggleAllMarkersBtn", "shareBtn", "shareBtnLabel", "widget", "zoomBtn"]

  static LEGEND_STORAGE_KEY = "timeline_hidden_types"
  static ZOOM_YEAR_PX = { "1": "24px", "2": "48px" }

  // major_debut 以外はデフォルト非表示（初回訪問時のみ適用）
  static DEFAULT_HIDDEN_PHENOMENA = [
    "announcement", "formation", "first_live", "finish", "pending",
    "rename", "suspend", "restart", "limited", "live", "media", "unknown", "other"
  ]

  connect() {
    const urlHidden = new URLSearchParams(location.search).get("hidden")
    if (urlHidden !== null) {
      // URLパラメータあり（共有URL）→ localStorageを触らずURLの値で初期表示
      this.hiddenTypes = new Set(urlHidden ? urlHidden.split(",").filter(Boolean) : [])
      this._fromUrl = true
    } else {
      const raw = localStorage.getItem(this.constructor.LEGEND_STORAGE_KEY)
      if (raw === null) {
        this.hiddenTypes = new Set(this.constructor.DEFAULT_HIDDEN_PHENOMENA)
        localStorage.setItem(this.constructor.LEGEND_STORAGE_KEY, JSON.stringify([...this.hiddenTypes]))
      } else {
        this.hiddenTypes = new Set(JSON.parse(raw))
      }
      this._fromUrl = false
    }
    this._restoreLegend()
    this._updateToggleAllBtn()
    this._initStickyLegend()
    this._initRowObserver()
    this._onPopState = (e) => {
      const zoom = e.state?.zoom || new URLSearchParams(location.search).get("zoom") || "1"
      this._applyZoom(zoom, false)
    }
    window.addEventListener("popstate", this._onPopState)
  }

  disconnect() {
    this._legendObserver?.disconnect()
    this._rowObserver?.disconnect()
    window.removeEventListener("popstate", this._onPopState)
  }

  toggleType(event) {
    const item = event.currentTarget
    const type = item.dataset.type
    if (this.hiddenTypes.has(type)) {
      this.hiddenTypes.delete(type)
      item.classList.remove("opacity-40", "line-through")
      item.setAttribute("aria-pressed", "false")
    } else {
      this.hiddenTypes.add(type)
      item.classList.add("opacity-40", "line-through")
      item.setAttribute("aria-pressed", "true")
    }
    this._applyVisibility(type)
    this._updateToggleAllBtn()
    // 共有URL由来でも、ユーザーが手動変更した時点からlocalStorageに保存する
    this._fromUrl = false
    localStorage.setItem(this.constructor.LEGEND_STORAGE_KEY, JSON.stringify([...this.hiddenTypes]))
  }

  _restoreLegend() {
    this.hiddenTypes.forEach(type => {
      this._applyVisibility(type)
      const btn = this.element.querySelector(`[data-type='${type}']`)
      if (btn) {
        btn.classList.add("opacity-40", "line-through")
        btn.setAttribute("aria-pressed", "true")
      }
    })
  }

  toggleAllMarkers() {
    const btns = this.markerLegendTarget.querySelectorAll("[data-type]")
    const types = [...btns].map(b => b.dataset.type)
    const allHidden = types.every(t => this.hiddenTypes.has(t))

    types.forEach(type => {
      if (allHidden) {
        this.hiddenTypes.delete(type)
      } else {
        this.hiddenTypes.add(type)
      }
      this._applyVisibility(type)
    })

    btns.forEach(btn => {
      btn.classList.toggle("opacity-40", !allHidden)
      btn.classList.toggle("line-through", !allHidden)
      btn.setAttribute("aria-pressed", allHidden ? "false" : "true")
    })

    this._updateToggleAllBtn()
    this._fromUrl = false
    localStorage.setItem(this.constructor.LEGEND_STORAGE_KEY, JSON.stringify([...this.hiddenTypes]))
  }

  setZoom(event) {
    this._applyZoom(event.currentTarget.dataset.zoomValue, true)
  }

  _applyZoom(zoom, pushState) {
    if (!this.hasWidgetTarget) return
    const widget = this.widgetTarget
    const yearPx = this.constructor.ZOOM_YEAR_PX[zoom] || "24px"

    widget.style.setProperty("--year-px", yearPx)
    widget.style.setProperty("--year-grid-fine-alpha", zoom === "2" ? "0.15" : "0")
    widget.dataset.zoom = zoom

    widget.querySelectorAll(".timeline-year-label-minor").forEach(el => {
      el.classList.toggle("hidden", zoom !== "2")
      el.toggleAttribute("aria-hidden", zoom !== "2")
    })

    if (this.hasZoomBtnTarget) {
      this.zoomBtnTargets.forEach(btn => {
        const active = btn.dataset.zoomValue === zoom
        btn.classList.toggle("bg-indigo-600", active)
        btn.classList.toggle("border-indigo-600", active)
        btn.classList.toggle("text-white", active)
        btn.classList.toggle("font-medium", active)
        btn.classList.toggle("border-zinc-300", !active)
        btn.classList.toggle("dark:border-zinc-600", !active)
        btn.classList.toggle("text-zinc-600", !active)
        btn.classList.toggle("dark:text-zinc-400", !active)
        btn.setAttribute("aria-current", active ? "true" : "false")
      })
    }

    if (pushState) {
      const params = new URLSearchParams(location.search)
      if (zoom === "1") {
        params.delete("zoom")
      } else {
        params.set("zoom", zoom)
      }
      const qs = params.toString()
      history.pushState({ zoom }, "", `${location.pathname}${qs ? "?" + qs : ""}`)
    }
  }

  async share() {
    const params = new URLSearchParams(location.search)

    // 凡例: 非表示タイプをパラメータに反映
    if (this.hiddenTypes.size > 0) {
      params.set("hidden", [...this.hiddenTypes].join(","))
    } else {
      params.delete("hidden")
    }

    // 追加バンド: localStorageから取得
    const bands = JSON.parse(localStorage.getItem("timeline_added_bands") || "[]")
    if (bands.length > 0) {
      params.set("bands", bands.join(","))
    } else {
      params.delete("bands")
    }

    const url = `${location.origin}${location.pathname}?${params.toString()}`

    if (navigator.share) {
      try {
        await navigator.share({ url })
        return
      } catch (e) {
        if (e.name === "AbortError") return  // ユーザーがキャンセル → 何もしない
        // それ以外（デスクトップで share が使えない等）→ クリップボードにフォールバック
      }
    }
    try {
      await navigator.clipboard.writeText(url)
      this._flashShareBtn("コピーしました！")
    } catch (e) {
      console.error("share copy error:", e)
    }
  }

  _flashShareBtn(label) {
    if (!this.hasShareBtnLabelTarget) return
    const original = this.shareBtnLabelTarget.textContent
    this.shareBtnLabelTarget.textContent = label
    setTimeout(() => { this.shareBtnLabelTarget.textContent = original }, 2000)
  }

  _updateToggleAllBtn() {
    if (!this.hasToggleAllMarkersBtnTarget || !this.hasMarkerLegendTarget) return
    const types = [...this.markerLegendTarget.querySelectorAll("[data-type]")].map(b => b.dataset.type)
    const allHidden = types.length > 0 && types.every(t => this.hiddenTypes.has(t))
    this.toggleAllMarkersBtnTarget.textContent = allHidden ? "全表示" : "全非表示"
  }

  _initRowObserver() {
    if (!this.hasBodyTarget) return
    this._rowObserver = new MutationObserver(mutations => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.nodeType !== Node.ELEMENT_NODE) continue
          this.hiddenTypes.forEach(type => {
            node.querySelectorAll(`[data-marker-type='${type}']`).forEach(el => {
              el.style.display = "none"
            })
          })
        }
      }
    })
    this._rowObserver.observe(this.bodyTarget, { childList: true, subtree: true })
  }

  _initStickyLegend() {
    if (!this.hasLegendContainerTarget) return
    const updateHeaderTop = () => {
      this.headerTarget.style.top = this.legendContainerTarget.offsetHeight + "px"
    }
    updateHeaderTop()
    this._legendObserver = new ResizeObserver(updateHeaderTop)
    this._legendObserver.observe(this.legendContainerTarget)
  }

  _applyVisibility(type) {
    const hidden = this.hiddenTypes.has(type)
    this.bodyTarget.querySelectorAll(`[data-row-type='${type}']`).forEach(row => {
      row.classList.toggle("hidden", hidden)
    })
    this.bodyTarget.querySelectorAll(`[data-marker-type='${type}']`).forEach(marker => {
      marker.style.display = hidden ? "none" : ""
    })
  }

  syncHeader() {
    this.headerTarget.scrollLeft = this.bodyTarget.scrollLeft
  }

  show(event) {
    const text = event.currentTarget.dataset.tooltip
    if (!text) return
    this.tooltipTarget.textContent = text
    this.tooltipTarget.classList.remove("hidden")
    this._position(event)
  }

  move(event) {
    this._position(event)
  }

  hide() {
    this.tooltipTarget.classList.add("hidden")
  }

  _position(event) {
    const el = this.tooltipTarget
    const x = event.clientX - el.offsetWidth + 4
    const y = event.clientY + 14
    const vh = window.innerHeight
    el.style.left = Math.max(0, x) + "px"
    el.style.top  = (y + el.offsetHeight > vh ? event.clientY - el.offsetHeight - 8 : y) + "px"
  }
}
