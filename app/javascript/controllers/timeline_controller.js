import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header", "body", "tooltip", "legendContainer"]

  static LEGEND_STORAGE_KEY = "timeline_hidden_types"

  // major_debut 以外はデフォルト非表示（初回訪問時のみ適用）
  static DEFAULT_HIDDEN_PHENOMENA = [
    "announcement", "formation", "first_live", "finish", "pending",
    "rename", "suspend", "restart", "limited", "live", "media", "unknown", "other"
  ]

  connect() {
    const raw = localStorage.getItem(this.constructor.LEGEND_STORAGE_KEY)
    if (raw === null) {
      this.hiddenTypes = new Set(this.constructor.DEFAULT_HIDDEN_PHENOMENA)
      localStorage.setItem(this.constructor.LEGEND_STORAGE_KEY, JSON.stringify([...this.hiddenTypes]))
    } else {
      this.hiddenTypes = new Set(JSON.parse(raw))
    }
    this._restoreLegend()
    this._initStickyLegend()
  }

  disconnect() {
    this._legendObserver?.disconnect()
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
      marker.classList.toggle("hidden", hidden)
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
