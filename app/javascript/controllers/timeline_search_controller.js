import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "suggestions", "modeBtn", "clearBtn"]

  static STORAGE_KEY = "timeline_added_bands"
  static HTML_CACHE_PREFIX = "timeline_unit_html_v6_"

  connect() {
    this.debounceTimer = null
    this.addedKeys = new Set()
    this.selectedIndex = -1
    this.mode = "band"
    this.handleClickOutside = this._onClickOutside.bind(this)
    document.addEventListener("click", this.handleClickOutside)

    const urlBands = new URLSearchParams(location.search).get("bands")
    if (urlBands !== null) {
      // URLパラメータあり（共有URL）→ localStorageを上書きせずURLの値で復元
      const keys = urlBands ? urlBands.split(",").filter(Boolean) : []
      this._restoreKeys(keys)
    } else {
      this._restoreFromStorage()
    }
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

  setMode(event) {
    const btn = event.currentTarget
    this.mode = btn.dataset.mode
    this.inputTarget.value = ""
    this.hideSuggestions()
    this.inputTarget.placeholder = this.mode === "person" ? "人物を検索..." : "バンドを追加..."
    this.modeBtnTargets.forEach(b => {
      const active = b.dataset.mode === this.mode
      b.classList.toggle("bg-indigo-600", active)
      b.classList.toggle("text-white", active)
      b.classList.toggle("font-medium", active)
      b.classList.toggle("text-zinc-600", !active)
      b.classList.toggle("dark:text-zinc-400", !active)
      b.setAttribute("aria-pressed", active ? "true" : "false")
    })
  }

  async fetchSuggestions(q) {
    const searchUrl = this.mode === "person"
      ? this.inputTarget.dataset.personSearchUrl
      : this.inputTarget.dataset.searchUrl
    try {
      const res = await fetch(`${searchUrl}?q=${encodeURIComponent(q)}`, {
        headers: { "Accept": "application/json" }
      })
      if (!res.ok) return
      const results = await res.json()
      this.renderSuggestions(results)
    } catch (e) {
      console.error("timeline-search fetchSuggestions error:", e)
    }
  }

  renderSuggestions(results) {
    this.selectedIndex = -1
    if (!results.length) {
      this.hideSuggestions()
      return
    }

    this.suggestionsTarget.innerHTML = results.map(u => {
      const already = this.mode === "band" && this.addedKeys.has(u.key)
      const cls = already ? "opacity-50 cursor-default" : "cursor-pointer hover:bg-zinc-100 dark:hover:bg-zinc-700"
      const badge = already ? `<span class="text-xs text-zinc-400 whitespace-nowrap">追加済み</span>` : ""
      return `<li data-key="${this.esc(u.key)}" class="px-3 py-2 flex items-center justify-between gap-2 ${cls}">
                <span class="truncate text-zinc-900 dark:text-zinc-100">${this.esc(u.name)}</span>${badge}
              </li>`
    }).join("")

    this.suggestionsTarget.querySelectorAll("li[data-key]").forEach(li => {
      if (this.mode === "person" || !this.addedKeys.has(li.dataset.key)) {
        li.addEventListener("click", () => {
          const name = li.querySelector("span").textContent.trim()
          if (this.mode === "person") {
            this.addPersonUnits(li.dataset.key, name)
          } else {
            this.addUnit(li.dataset.key, name)
          }
        })
      }
    })
    this.suggestionsTarget.classList.remove("hidden")
  }

  async addPersonUnits(personKey, personName) {
    this.hideSuggestions()
    this.inputTarget.value = ""
    try {
      const baseUrl = this.inputTarget.dataset.personUnitsBaseUrl
      const res = await fetch(`${baseUrl}/${encodeURIComponent(personKey)}/units`, {
        headers: { "Accept": "application/json" }
      })
      if (!res.ok) throw new Error(`fetch failed: ${res.status}`)
      const { unit_keys } = await res.json()
      const newKeys = unit_keys.filter(k => !this.addedKeys.has(k))
      if (!newKeys.length) return
      await this._restoreKeys(newKeys)
      this._saveToStorage()
    } catch (e) {
      console.error("timeline-search addPersonUnits error:", e)
      alert(`「${personName}」の関連バンドの追加に失敗しました`)
    }
  }

  get _cacheKeyPrefix() {
    try {
      const params = new URL(this.inputTarget.dataset.unitUrl, window.location.origin).searchParams
      return this.constructor.HTML_CACHE_PREFIX + (params.get("ym") || "")
    } catch {
      return this.constructor.HTML_CACHE_PREFIX
    }
  }

  // ユーザー操作による1件追加
  async addUnit(key, name, { scroll = true } = {}) {
    this.hideSuggestions()
    this.inputTarget.value = ""
    const unitUrl = this.inputTarget.dataset.unitUrl
    try {
      const cacheKey = this._cacheKeyPrefix + "_" + key
      let html = this._getValidCache(cacheKey)
      if (!html) {
        try {
          const url = new URL(unitUrl, window.location.origin)
          url.searchParams.set("key", key)
          const res = await fetch(url.toString(), { headers: { "Accept": "text/html" } })
          if (!res.ok) throw new Error(`fetch failed: ${res.status}`)
          html = await res.text()
          sessionStorage.setItem(cacheKey, html)
        } catch {
          alert(`「${name}」の追加に失敗しました`)
          return
        }
      }
      this.addedKeys.add(key)
      this._saveToStorage()
      this._insertRow(key, html, { scroll })
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
    this._updateClearBtn()
  }

  _updateClearBtn() {
    if (this.hasClearBtnTarget) {
      this.clearBtnTarget.classList.toggle("hidden", this.addedKeys.size === 0)
    }
  }

  clearAll() {
    const rows = document.getElementById("timeline-rows-inner") || document.getElementById("timeline-rows")
    if (rows) {
      Array.from(rows.querySelectorAll("[data-row-type='added']")).forEach(r => r.remove())
    }
    const prefix = this._cacheKeyPrefix
    this.addedKeys.forEach(key => sessionStorage.removeItem(prefix + "_" + key))
    this.addedKeys.clear()
    this._saveToStorage()
  }

  // キャッシュから HTML を取得。data-start-year がなければ無効とみなしキャッシュ削除
  _getValidCache(cacheKey) {
    const html = sessionStorage.getItem(cacheKey)
    if (!html) return null
    const probe = document.createElement("div")
    probe.innerHTML = html.trim()
    if (!probe.firstElementChild?.dataset.startYear) {
      sessionStorage.removeItem(cacheKey)
      return null
    }
    return html
  }

  // DOM への行挿入・スタイル適用・削除ボタン付与
  _insertRow(key, html, { scroll = false } = {}) {
    const rows = document.getElementById("timeline-rows-inner") || document.getElementById("timeline-rows")
    if (!rows) return
    const tmp = document.createElement("div")
    tmp.innerHTML = html.trim()
    const row = tmp.firstElementChild
    if (!row) return

    const startYear = parseFloat(row.dataset.startYear)
    const after = Array.from(rows.children).find(r => parseFloat(r.dataset.startYear) > startYear)
    after ? rows.insertBefore(row, after) : rows.appendChild(row)

    if (scroll) {
      row.scrollIntoView({ behavior: "smooth", block: "center" })
      requestAnimationFrame(() => {
        const bars = row.querySelectorAll("div.absolute.rounded")
        if (!bars.length) return
        const lefts = Array.from(bars).map(b => {
          const v = parseFloat(b.style.left)
          return isNaN(v) ? Infinity : v
        })
        const minLeft = Math.min(...lefts)
        const body = document.getElementById("timeline-rows")
        if (body && isFinite(minLeft)) body.scrollLeft = Math.max(0, minLeft - 20)
      })
    }

    row.dataset.rowType = "added"
    const hiddenTypes = JSON.parse(localStorage.getItem("timeline_hidden_types") || "[]")
    if (hiddenTypes.includes("added")) row.classList.add("hidden")
    row.querySelectorAll("div.absolute.rounded").forEach(bar => {
      bar.style.backgroundColor = "#22c55e"
    })

    const nameCell = row.querySelector("div[style*='width']")
    if (nameCell) {
      nameCell.classList.add("timeline-added-name-cell")
      const btn = document.createElement("button")
      btn.type = "button"
      btn.textContent = "✕"
      btn.setAttribute("aria-label", "行を削除")
      btn.className = "flex-shrink-0 ml-1 text-xs text-zinc-400 hover:text-red-500 leading-none"
      btn.addEventListener("click", () => {
        this.addedKeys.delete(key)
        this._saveToStorage()
        sessionStorage.removeItem(this._cacheKeyPrefix + "_" + key)
        row.remove()
      })
      nameCell.appendChild(btn)
    }
  }

  // キーの配列を復元（共有URL・localStorage 両方から使用）
  async _restoreKeys(keys) {
    if (!keys.length) return

    // キャッシュ済みをまず即挿入
    const uncached = []
    for (const key of keys) {
      const html = this._getValidCache(this._cacheKeyPrefix + "_" + key)
      if (html) {
        this.addedKeys.add(key)
        this._insertRow(key, html)
      } else {
        uncached.push(key)
      }
    }

    if (!uncached.length) {
      this._updateClearBtn()
      return
    }

    // 未キャッシュ分を1リクエストでバッチ取得
    try {
      const unitsUrl = this.inputTarget.dataset.unitsUrl
      const url = new URL(unitsUrl, window.location.origin)
      uncached.forEach(key => url.searchParams.append("keys[]", key))
      const res = await fetch(url.toString(), { headers: { "Accept": "application/json" } })
      if (!res.ok) return
      const htmlMap = await res.json()
      for (const key of uncached) {
        const html = htmlMap[key]
        if (!html) continue
        sessionStorage.setItem(this._cacheKeyPrefix + "_" + key, html)
        this.addedKeys.add(key)
        this._insertRow(key, html)
      }
    } catch (e) {
      console.error("timeline-search _restoreKeys error:", e)
    }
    this._updateClearBtn()
  }

  _restoreFromStorage() {
    const saved = JSON.parse(localStorage.getItem(this.constructor.STORAGE_KEY) || "[]")
    this._restoreKeys(saved)
  }
}
