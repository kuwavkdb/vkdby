import { Controller } from "@hotwired/stimulus"

const UNIT_BTN_CLASS = "flex-none px-2 py-1 text-xs rounded border border-indigo-300 bg-indigo-50 text-indigo-700 dark:bg-indigo-900 dark:text-indigo-300 dark:border-indigo-700 whitespace-nowrap"
const PERSON_BTN_CLASS = "flex-none px-2 py-1 text-xs rounded border border-green-300 bg-green-50 text-green-700 dark:bg-green-900 dark:text-green-300 dark:border-green-700 whitespace-nowrap"
const UNIT_CHIP_CLASS = "artist-chip inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-200"
const PERSON_CHIP_CLASS = "artist-chip inline-flex items-center gap-1 px-3 py-1 rounded-full text-sm bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"

export default class extends Controller {
  static targets = ["row", "container", "template", "hiddenField"]
  static values = {
    urlUnits: String,
    urlPeople: String
  }

  connect() {
    this.timeout = null
    this.handleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener("click", this.handleClickOutside)
    this.syncHiddenField()
  }

  disconnect() {
    document.removeEventListener("click", this.handleClickOutside)
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.rowTargets.forEach(row => this.hideResults(row))
    }
  }

  addRow(event) {
    event.preventDefault()
    const clone = this.templateTarget.content.cloneNode(true)
    this.containerTarget.appendChild(clone)
    const rows = this.rowTargets
    const newRow = rows[rows.length - 1]
    if (newRow) {
      const input = newRow.querySelector(".artist-search-input")
      if (input) input.focus()
    }
  }

  removeRow(event) {
    const row = event.currentTarget.closest("[data-artist-rows-target='row']")
    row.remove()
    this.syncHiddenField()
  }

  toggleMode(event) {
    const btn = event.currentTarget
    const row = btn.closest("[data-artist-rows-target='row']")
    const currentMode = row.dataset.mode || "unit"
    const newMode = currentMode === "unit" ? "person" : "unit"
    row.dataset.mode = newMode

    if (newMode === "unit") {
      btn.textContent = "Units"
      btn.className = UNIT_BTN_CLASS
    } else {
      btn.textContent = "People"
      btn.className = PERSON_BTN_CLASS
    }

    const input = row.querySelector(".artist-search-input")
    const previousQuery = row.querySelector(".artist-name-hidden").value || input.value
    this.clearRowSelection(row)

    if (previousQuery.length >= 2) {
      input.value = previousQuery
      this.performSearch(row, previousQuery)
    }
  }

  clearSelection(event) {
    const row = event.currentTarget.closest("[data-artist-rows-target='row']")
    this.clearRowSelection(row)
  }

  clearRowSelection(row) {
    row.querySelector(".artist-name-hidden").value = ""
    row.querySelector(".artist-key-hidden").value = ""
    const oldKeyEl = row.querySelector(".artist-old-key-hidden")
    if (oldKeyEl) oldKeyEl.value = ""

    const selectedDisplay = row.querySelector(".artist-selected-display")
    selectedDisplay.classList.add("hidden")
    selectedDisplay.classList.remove("flex")

    const searchWrapper = row.querySelector(".artist-search-wrapper")
    searchWrapper.classList.remove("hidden")

    const input = row.querySelector(".artist-search-input")
    const mode = row.dataset.mode || "unit"
    input.placeholder = mode === "unit" ? "ユニット名で検索..." : "個人名で検索..."
    input.value = ""
    input.focus()

    this.hideResults(row)
    this.syncHiddenField()
  }

  onSearchInput(event) {
    const input = event.currentTarget
    const row = input.closest("[data-artist-rows-target='row']")
    const query = input.value.trim()

    clearTimeout(this.timeout)

    if (query.length < 2) {
      this.hideResults(row)
      return
    }

    this.timeout = setTimeout(() => {
      this.performSearch(row, query)
    }, 300)
  }

  onSearchFocus(event) {
    const input = event.currentTarget
    const row = input.closest("[data-artist-rows-target='row']")
    const query = input.value.trim()
    if (query.length >= 2) {
      this.performSearch(row, query)
    }
  }

  onKeydown(event) {
    const input = event.currentTarget
    const row = input.closest("[data-artist-rows-target='row']")
    const resultsEl = row.querySelector(".artist-results")
    const items = Array.from(resultsEl.querySelectorAll("[data-result-item]"))
    const activeEl = resultsEl.querySelector("[data-active='true']")
    const activeIndex = activeEl ? items.indexOf(activeEl) : -1

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        if (resultsEl.classList.contains("hidden")) return
        this.setActiveResult(items, Math.min(activeIndex + 1, items.length - 1))
        break
      case "ArrowUp":
        event.preventDefault()
        if (resultsEl.classList.contains("hidden")) return
        this.setActiveResult(items, Math.max(activeIndex - 1, 0))
        break
      case "Enter":
        event.preventDefault()
        if (activeEl) activeEl.click()
        break
      case "Escape":
        this.hideResults(row)
        input.blur()
        break
    }
  }

  setActiveResult(items, index) {
    items.forEach((item, i) => {
      if (i === index) {
        item.dataset.active = "true"
        item.classList.add("bg-gray-100", "dark:bg-gray-700")
        item.scrollIntoView({ block: "nearest" })
      } else {
        item.dataset.active = "false"
        item.classList.remove("bg-gray-100", "dark:bg-gray-700")
      }
    })
  }

  async performSearch(row, query) {
    const mode = row.dataset.mode || "unit"
    const url = mode === "unit" ? this.urlUnitsValue : this.urlPeopleValue

    try {
      const response = await fetch(`${url}?q=${encodeURIComponent(query)}`, {
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
      if (!response.ok) throw new Error("Search failed")
      const data = await response.json()
      this.displayResults(row, data)
    } catch (e) {
      console.error("Artist search failed", e)
    }
  }

  displayResults(row, items) {
    const resultsEl = row.querySelector(".artist-results")

    if (items.length === 0) {
      this.hideResults(row)
      return
    }

    resultsEl.innerHTML = items.map(item => `
      <div class="px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer"
           data-result-item
           data-active="false"
           data-action="click->artist-rows#selectItem"
           data-name="${this.escapeHtml(item.name)}"
           data-key="${this.escapeHtml(item.key || "")}"
           data-destination-key="${this.escapeHtml(item.destination_key || "")}">
        <div class="font-medium text-gray-900 dark:text-gray-100">${this.escapeHtml(item.name)}</div>
        ${item.name_kana ? `<div class="text-xs text-gray-500 dark:text-gray-400">${this.escapeHtml(item.name_kana)}</div>` : ""}
        ${item.destination_key ? `<div class="text-xs text-amber-600 dark:text-amber-400">→ ${this.escapeHtml(item.destination_key)}</div>` : ""}
      </div>
    `).join("")

    resultsEl.classList.remove("hidden")
  }

  async selectItem(event) {
    const resultItem = event.currentTarget
    const row = resultItem.closest("[data-artist-rows-target='row']")
    const destinationKey = resultItem.dataset.destinationKey || ""
    const mode = row.dataset.mode || "unit"

    if (destinationKey) {
      const url = mode === "unit" ? this.urlUnitsValue : this.urlPeopleValue
      try {
        const response = await fetch(`${url}?q=${encodeURIComponent(destinationKey)}`, {
          headers: { "Accept": "application/json", "X-Requested-With": "XMLHttpRequest" }
        })
        const data = await response.json()
        const dest = data.find(item => item.key === destinationKey)
        if (dest) {
          this.applySelection(row, dest.name, dest.key, mode)
          return
        }
      } catch (e) {
        console.error("Destination key resolution failed", e)
      }
    }

    this.applySelection(row, resultItem.dataset.name, resultItem.dataset.key || "", mode)
  }

  applySelection(row, name, key, mode) {
    row.querySelector(".artist-name-hidden").value = name
    row.querySelector(".artist-key-hidden").value = key

    const selectedDisplay = row.querySelector(".artist-selected-display")
    selectedDisplay.querySelector(".artist-name-display").textContent = name
    selectedDisplay.querySelector(".artist-chip").className = mode === "person" ? PERSON_CHIP_CLASS : UNIT_CHIP_CLASS
    selectedDisplay.classList.remove("hidden")
    selectedDisplay.classList.add("flex")

    row.querySelector(".artist-search-wrapper").classList.add("hidden")

    this.hideResults(row)
    this.syncHiddenField()
  }

  onAliasInput() {
    this.syncHiddenField()
  }

  hideResults(row) {
    const resultsEl = row.querySelector(".artist-results")
    resultsEl.classList.add("hidden")
    resultsEl.innerHTML = ""
  }

  syncHiddenField() {
    const data = this.rowTargets.map(row => {
      const name = row.querySelector(".artist-name-hidden").value.trim()
      const key = row.querySelector(".artist-key-hidden").value.trim()
      const oldKeyEl = row.querySelector(".artist-old-key-hidden")
      const oldKey = oldKeyEl ? oldKeyEl.value.trim() : ""
      const alias = row.querySelector(".artist-alias-input").value.trim()
      if (!name) return null
      const entry = { name }
      if (key) entry.key = key
      if (oldKey) entry.old_key = oldKey
      if (alias) entry.alias = alias
      return entry
    }).filter(Boolean)

    this.hiddenFieldTarget.value = JSON.stringify(data)
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
