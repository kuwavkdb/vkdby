import { Controller } from "@hotwired/stimulus"

// Trendフォームの会場入力欄（issue #1689）。会場は1件のみなので、複数選択の
// autocomplete_controller とは分け、候補から1件を選ぶと hidden の venue_id に入れる。
export default class extends Controller {
  static targets = ["input", "results", "hiddenField", "selected", "selectedName"]
  static values = { url: String }

  connect() {
    this.timeout = null
    this.activeIndex = -1
    this.handleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener("click", this.handleClickOutside)
    this.toggleSelected()
  }

  disconnect() {
    document.removeEventListener("click", this.handleClickOutside)
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) this.hideResults()
  }

  search() {
    clearTimeout(this.timeout)
    const query = this.inputTarget.value.trim()
    if (query.length < 1) {
      this.hideResults()
      return
    }
    this.timeout = setTimeout(() => this.performSearch(query), 300)
  }

  async performSearch(query) {
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json", "X-Requested-With": "XMLHttpRequest" }
      })
      if (!response.ok) throw new Error("Search failed")
      this.displayResults(await response.json())
    } catch (error) {
      console.error("Venue picker error:", error)
    }
  }

  displayResults(items) {
    this.activeIndex = -1
    if (items.length === 0) {
      this.resultsTarget.innerHTML =
        `<div class="px-4 py-2 text-sm text-gray-500 dark:text-gray-400">該当する会場がありません</div>`
      this.showResults()
      return
    }

    this.resultsTarget.innerHTML = items.map(item => `
      <div role="option" class="px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer"
           data-action="click->venue-picker#selectItem"
           data-id="${item.id}"
           data-name="${this.escapeHtml(item.name)}">
        <div class="font-medium text-gray-900 dark:text-gray-100">${this.escapeHtml(item.name)}</div>
        ${item.location ? `<div class="text-xs text-gray-500 dark:text-gray-400">${this.escapeHtml(item.location)}</div>` : ""}
      </div>
    `).join("")
    this.showResults()
  }

  onKeydown(event) {
    const items = Array.from(this.resultsTarget.querySelectorAll("[data-id]"))
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        if (items.length === 0) return
        this.activeIndex = Math.min(this.activeIndex + 1, items.length - 1)
        this.highlight(items)
        break
      case "ArrowUp":
        event.preventDefault()
        if (items.length === 0) return
        this.activeIndex = Math.max(this.activeIndex - 1, 0)
        this.highlight(items)
        break
      case "Enter":
        // 候補の選択中はフォーム送信させない
        if (!this.resultsTarget.classList.contains("hidden")) {
          event.preventDefault()
          if (items[this.activeIndex]) items[this.activeIndex].click()
        }
        break
      case "Escape":
        this.hideResults()
        break
    }
  }

  highlight(items) {
    items.forEach((item, index) => {
      const active = index === this.activeIndex
      item.classList.toggle("bg-gray-100", active)
      item.classList.toggle("dark:bg-gray-700", active)
      item.setAttribute("aria-selected", active ? "true" : "false")
    })
    items[this.activeIndex]?.scrollIntoView({ block: "nearest" })
  }

  selectItem(event) {
    this.hiddenFieldTarget.value = event.currentTarget.dataset.id
    this.selectedNameTarget.textContent = event.currentTarget.dataset.name
    this.inputTarget.value = ""
    this.hideResults()
    this.toggleSelected()
  }

  clear() {
    this.hiddenFieldTarget.value = ""
    this.selectedNameTarget.textContent = ""
    this.toggleSelected()
    this.inputTarget.focus()
  }

  toggleSelected() {
    const hasValue = this.hiddenFieldTarget.value !== ""
    this.selectedTarget.classList.toggle("hidden", !hasValue)
  }

  showResults() {
    this.resultsTarget.classList.remove("hidden")
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  hideResults() {
    this.activeIndex = -1
    this.resultsTarget.classList.add("hidden")
    this.inputTarget.setAttribute("aria-expanded", "false")
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
