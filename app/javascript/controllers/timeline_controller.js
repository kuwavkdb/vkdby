import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header", "body", "tooltip"]

  static LEGEND_STORAGE_KEY = "timeline_hidden_types"

  connect() {
    const saved = JSON.parse(localStorage.getItem(this.constructor.LEGEND_STORAGE_KEY) || "[]")
    this.hiddenTypes = new Set(saved)
    this._restoreLegend()
    this._scrollToFirstBar()
  }

  _scrollToFirstBar() {
    const bars = this.bodyTarget.querySelectorAll("div.absolute.rounded")
    if (!bars.length) return
    const minLeft = Math.min(...Array.from(bars).map(b => parseFloat(b.style.left) || Infinity))
    if (isFinite(minLeft)) {
      this.bodyTarget.scrollLeft = Math.max(0, minLeft - 20)
    }
  }

  toggleType(event) {
    const item = event.currentTarget
    const type = item.dataset.type
    if (this.hiddenTypes.has(type)) {
      this.hiddenTypes.delete(type)
      item.classList.remove("opacity-40", "line-through")
    } else {
      this.hiddenTypes.add(type)
      item.classList.add("opacity-40", "line-through")
    }
    this._applyVisibility(type)
    localStorage.setItem(this.constructor.LEGEND_STORAGE_KEY, JSON.stringify([...this.hiddenTypes]))
  }

  _restoreLegend() {
    this.hiddenTypes.forEach(type => {
      this._applyVisibility(type)
      const btn = this.element.querySelector(`[data-type='${type}']`)
      if (btn) btn.classList.add("opacity-40", "line-through")
    })
  }

  _applyVisibility(type) {
    const hidden = this.hiddenTypes.has(type)
    this.bodyTarget.querySelectorAll(`[data-row-type='${type}']`).forEach(row => {
      row.classList.toggle("hidden", hidden)
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
