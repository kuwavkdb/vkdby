import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header", "body", "tooltip"]

  connect() {
    this.hiddenTypes = new Set()
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
  }

  _applyVisibility(type) {
    const hidden = this.hiddenTypes.has(type)
    if (type === "debut") {
      this.bodyTarget.querySelectorAll("[data-marker-type='debut']").forEach(el => {
        el.classList.toggle("hidden", hidden)
      })
    } else {
      this.bodyTarget.querySelectorAll(`[data-row-type='${type}']`).forEach(row => {
        row.classList.toggle("hidden", hidden)
      })
    }
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
