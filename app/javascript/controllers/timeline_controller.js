import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header", "body", "tooltip", "zoomLabel"]

  static LEGEND_STORAGE_KEY = "timeline_hidden_types"
  static YEAR_PX_KEY        = "timeline_year_px"
  static YEAR_PX_VALUES     = [24, 36]

  connect() {
    const saved = JSON.parse(localStorage.getItem(this.constructor.LEGEND_STORAGE_KEY) || "[]")
    this.hiddenTypes = new Set(saved)
    this._restoreLegend()

    const savedPx = parseInt(localStorage.getItem(this.constructor.YEAR_PX_KEY), 10)
    this.yearPx = this.constructor.YEAR_PX_VALUES.includes(savedPx) ? savedPx : 24
    if (this.yearPx !== 24) this._applyYearPx(this.yearPx)
    this._updateZoomLabel()

    this._handleRowAdded = ({ detail: { row } }) => {
      if (this.yearPx !== 24) this._applyYearPxToChartDiv(row.querySelector("[data-chart-area]"), this.yearPx)
    }
    this.element.addEventListener("timeline:row-added", this._handleRowAdded)
  }

  disconnect() {
    this.element.removeEventListener("timeline:row-added", this._handleRowAdded)
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

  toggleZoom() {
    const values = this.constructor.YEAR_PX_VALUES
    this.yearPx = values[(values.indexOf(this.yearPx) + 1) % values.length]
    localStorage.setItem(this.constructor.YEAR_PX_KEY, this.yearPx)
    this._applyYearPx(this.yearPx)
    this._updateZoomLabel()
  }

  _updateZoomLabel() {
    if (this.hasZoomLabelTarget) {
      this.zoomLabelTarget.textContent = this.yearPx === 24 ? "標準" : "拡大"
    }
  }

  _applyYearPx(px) {
    // ヘッダー年ラベル
    const headerChart = this.headerTarget.querySelector("[data-year-min]")
    if (headerChart) {
      const yearMin = parseInt(headerChart.dataset.yearMin, 10)
      const yearMax = parseInt(headerChart.dataset.yearMax, 10)
      headerChart.style.width = `${(yearMax - yearMin + 1) * px}px`
      headerChart.querySelectorAll("[data-header-year]").forEach(el => {
        el.style.left = `${(parseInt(el.dataset.headerYear, 10) - yearMin) * px}px`
      })
      const lastTick = headerChart.querySelector("[data-header-last-tick]")
      if (lastTick) lastTick.style.left = `${(yearMax - yearMin + 1) * px}px`
    }
    // 各行のチャートエリア
    this.bodyTarget.querySelectorAll("[data-chart-area]").forEach(chartDiv => {
      this._applyYearPxToChartDiv(chartDiv, px)
    })
  }

  _applyYearPxToChartDiv(chartDiv, px) {
    if (!chartDiv) return
    const yearMin = parseInt(chartDiv.dataset.yearMin, 10)
    const yearMax = parseInt(chartDiv.dataset.yearMax, 10)
    chartDiv.style.width = `${(yearMax - yearMin + 1) * px}px`
    // グリッド背景
    const gridSpan = px * 5
    const offset   = (5 - yearMin % 5) % 5 * px
    const grad = `repeating-linear-gradient(to right, transparent, transparent ${gridSpan - 2}px, rgba(113,113,122,0.35) ${gridSpan - 2}px, rgba(113,113,122,0.35) ${gridSpan}px)`
    chartDiv.style.backgroundImage    = grad
    chartDiv.style.backgroundSize     = `${gridSpan}px 100%`
    chartDiv.style.backgroundPosition = `${offset}px 0`
    // バー
    chartDiv.querySelectorAll("[data-bar-from]").forEach(bar => {
      const from = parseInt(bar.dataset.barFrom, 10)
      const to   = parseInt(bar.dataset.barTo, 10)
      bar.style.left  = `${(from - yearMin) * px}px`
      bar.style.width = `${Math.max((to - from + 1) * px, Math.floor(px / 2))}px`
    })
    // マーカー
    chartDiv.querySelectorAll("[data-marker-year]").forEach(marker => {
      const year  = parseInt(marker.dataset.markerYear, 10)
      const month = parseInt(marker.dataset.markerMonth, 10) || 1
      marker.style.left = `${(year - yearMin) * px + (month - 1) * px / 12}px`
    })
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
