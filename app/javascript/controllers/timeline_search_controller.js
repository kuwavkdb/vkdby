import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "suggestions"]

  static STORAGE_KEY = "timeline_added_bands"
  static HTML_CACHE_PREFIX = "timeline_unit_html_"

  connect() {
    this.debounceTimer = null
    this.addedKeys = new Set()
    this.selectedIndex = -1
    this.handleClickOutside = this._onClickOutside.bind(this)
    document.addEventListener("click", this.handleClickOutside)
    this._restoreFromStorage()
  }

  disconnect() {
    document.removeEventListener("click", this.handleClickOutside)
    clearTimeout(this.debounceTimer)
  }

  suggest() {
    clearTimeout(this.debounceTimer)
    const q = this.inputTarget.value.trim()
    if (q.length < 2) {
      this.hideSuggestions()
      return
    }
    this.debounceTimer = setTimeout(() => this.fetchSuggestions(q), 200)
  }

  keydown(event) {
    if (this.suggestionsTarget.classList.contains("hidden")) return
    const items = this.suggestionsTarget.querySelectorAll("li[data-key]")

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
        this.updateActive(items)
        break
      case "ArrowUp":
        event.preventDefault()
        this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
        this.updateActive(items)
        break
      case "Enter":
        event.preventDefault()
        if (this.selectedIndex >= 0 && items[this.selectedIndex]) {
          items[this.selectedIndex].click()
        }
        break
      case "Escape":
        this.hideSuggestions()
        break
    }
  }

  async fetchSuggestions(q) {
    const searchUrl = this.inputTarget.dataset.searchUrl
    try {
      const res = await fetch(`${searchUrl}?q=${encodeURIComponent(q)}`, {
        headers: { "Accept": "application/json" }
      })
      if (!res.ok) return
      const units = await res.json()
      this.renderSuggestions(units)
    } catch (e) {
      console.error("timeline-search fetchSuggestions error:", e)
    }
  }

  renderSuggestions(units) {
    this.selectedIndex = -1
    if (!units.length) {
      this.hideSuggestions()
      return
    }

    this.suggestionsTarget.innerHTML = units.map(u => {
      const already = this.addedKeys.has(u.key)
      const cls = already ? "opacity-50 cursor-default" : "cursor-pointer hover:bg-zinc-100 dark:hover:bg-zinc-700"
      const badge = already ? `<span class="text-xs text-zinc-400 whitespace-nowrap">追加済み</span>` : ""
      return `<li data-key="${this.esc(u.key)}" class="px-3 py-2 flex items-center justify-between gap-2 ${cls}">
                <span class="truncate text-zinc-900 dark:text-zinc-100">${this.esc(u.name)}</span>${badge}
              </li>`
    }).join("")

    this.suggestionsTarget.querySelectorAll("li[data-key]").forEach(li => {
      if (!this.addedKeys.has(li.dataset.key)) {
        li.addEventListener("click", () => {
          const name = li.querySelector("span").textContent.trim()
          this.addUnit(li.dataset.key, name)
        })
      }
    })
    this.suggestionsTarget.classList.remove("hidden")
  }

  get _zoom() {
    try {
      return new URL(this.inputTarget.dataset.unitUrl, window.location.origin).searchParams.get("zoom") || "1"
    } catch {
      return "1"
    }
  }

  async addUnit(key, name, { scroll = true } = {}) {
    this.hideSuggestions()
    this.inputTarget.value = ""
    const unitUrl = this.inputTarget.dataset.unitUrl
    try {
      const cacheKey = this.constructor.HTML_CACHE_PREFIX + this._zoom + "_" + key
      const fetchHtml = async () => {
        const url = new URL(unitUrl, window.location.origin)
        url.searchParams.set("key", key)
        const res = await fetch(url.toString(), {
          headers: { "Accept": "text/html" }
        })
        if (!res.ok) throw new Error(`fetch failed: ${res.status}`)
        return res.text()
      }
      let html = sessionStorage.getItem(cacheKey)
      if (html) {
        const probe = document.createElement("div")
        probe.innerHTML = html.trim()
        if (!probe.firstElementChild?.dataset.startYear) {
          sessionStorage.removeItem(cacheKey)
          html = null
        }
      }
      if (!html) {
        try {
          html = await fetchHtml()
          sessionStorage.setItem(cacheKey, html)
        } catch {
          alert(`「${name}」の追加に失敗しました`)
          return
        }
      }
      const rows = document.getElementById("timeline-rows")
      if (!rows) return
      this.addedKeys.add(key)
      this._saveToStorage()
      const tmp = document.createElement("div")
      tmp.innerHTML = html.trim()
      const row = tmp.firstElementChild
      if (!row) return
      const startYear = parseInt(row.dataset.startYear, 10)
      const after = Array.from(rows.children).find(r => parseInt(r.dataset.startYear, 10) > startYear)
      after ? rows.insertBefore(row, after) : rows.appendChild(row)
      if (scroll) row.scrollIntoView({ behavior: "smooth", block: "center" })
      row.dataset.rowType = "added"
      row.querySelectorAll("div.absolute.rounded").forEach(bar => {
        bar.style.backgroundColor = "#22c55e"
      })
      const nameCell = row.querySelector("div[style*='width']")
      if (nameCell) {
        nameCell.style.backgroundColor = "#dcfce7"
        const btn = document.createElement("button")
        btn.type = "button"
        btn.textContent = "✕"
        btn.setAttribute("aria-label", "行を削除")
        btn.className = "flex-shrink-0 ml-1 text-xs text-zinc-400 hover:text-red-500 leading-none"
        btn.addEventListener("click", () => {
          this.addedKeys.delete(key)
          this._saveToStorage()
          sessionStorage.removeItem(this.constructor.HTML_CACHE_PREFIX + key)
          row.remove()
        })
        nameCell.appendChild(btn)
      }
    } catch (e) {
      console.error("timeline-search addUnit error:", e)
    }
  }

  hideSuggestions() {
    this.suggestionsTarget.classList.add("hidden")
    this.suggestionsTarget.innerHTML = ""
    this.selectedIndex = -1
  }

  updateActive(items) {
    items.forEach((li, i) => {
      li.classList.toggle("bg-zinc-100", i === this.selectedIndex)
      li.classList.toggle("dark:bg-zinc-700", i === this.selectedIndex)
    })
  }

  esc(text) {
    const div = document.createElement("div")
    div.textContent = String(text)
    return div.innerHTML
  }

  _onClickOutside(event) {
    if (!this.element.contains(event.target)) this.hideSuggestions()
  }

  _saveToStorage() {
    localStorage.setItem(this.constructor.STORAGE_KEY, JSON.stringify([...this.addedKeys]))
  }

  _restoreFromStorage() {
    const saved = JSON.parse(localStorage.getItem(this.constructor.STORAGE_KEY) || "[]")
    saved.forEach(key => this.addUnit(key, key, { scroll: false }))
  }
}
