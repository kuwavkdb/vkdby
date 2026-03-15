import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header", "body", "tooltip"]

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
    const x = event.clientX + 14
    const y = event.clientY + 14
    const vw = window.innerWidth
    const vh = window.innerHeight
    el.style.left = (x + el.offsetWidth  > vw ? event.clientX - el.offsetWidth  - 8 : x) + "px"
    el.style.top  = (y + el.offsetHeight > vh ? event.clientY - el.offsetHeight - 8 : y) + "px"
  }
}
