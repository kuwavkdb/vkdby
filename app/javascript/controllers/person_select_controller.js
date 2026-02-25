import { Controller } from "@hotwired/stimulus"

// Single-select autocomplete for person lookup.
// Sets a hidden person_id field and optionally fills person_name.
export default class extends Controller {
  static targets = ["input", "results", "personId", "personName"]
  static values = { url: String }

  connect() {
    this.timeout = null
    this.activeIndex = -1
    this.handleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener('click', this.handleClickOutside)
  }

  disconnect() {
    document.removeEventListener('click', this.handleClickOutside)
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideResults()
    }
  }

  search() {
    clearTimeout(this.timeout)
    const query = this.inputTarget.value.trim()

    if (query.length < 2) {
      this.hideResults()
      return
    }

    this.timeout = setTimeout(() => this.performSearch(query), 300)
  }

  onKeydown(event) {
    const items = this.resultItems

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        if (this.resultsTarget.classList.contains('hidden')) return
        this.activeIndex = Math.min(this.activeIndex + 1, items.length - 1)
        this.highlightItem()
        break
      case 'ArrowUp':
        event.preventDefault()
        if (this.resultsTarget.classList.contains('hidden')) return
        this.activeIndex = Math.max(this.activeIndex - 1, 0)
        this.highlightItem()
        break
      case 'Enter':
        event.preventDefault()
        if (this.activeIndex >= 0 && items[this.activeIndex]) {
          items[this.activeIndex].click()
        }
        break
      case 'Escape':
        this.hideResults()
        this.inputTarget.blur()
        break
    }
  }

  get resultItems() {
    return Array.from(this.resultsTarget.querySelectorAll('[data-id]'))
  }

  highlightItem() {
    const items = this.resultItems
    items.forEach((item, index) => {
      if (index === this.activeIndex) {
        item.classList.add('bg-gray-100', 'dark:bg-gray-700')
      } else {
        item.classList.remove('bg-gray-100', 'dark:bg-gray-700')
      }
    })
    if (items[this.activeIndex]) {
      items[this.activeIndex].scrollIntoView({ block: 'nearest' })
    }
  }

  async performSearch(query) {
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      if (!response.ok) throw new Error('Search failed')
      const data = await response.json()
      this.displayResults(data)
    } catch (error) {
      console.error('Person select error:', error)
    }
  }

  displayResults(items) {
    this.activeIndex = -1

    if (items.length === 0) {
      this.hideResults()
      return
    }

    this.resultsTarget.innerHTML = items.map(item => `
      <div class="px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer"
           data-action="click->person-select#selectItem"
           data-id="${item.id}"
           data-name="${this.escapeHtml(item.name)}">
        <div class="font-medium text-gray-900 dark:text-gray-100">${this.escapeHtml(item.name)}</div>
        ${item.name_kana ? `<div class="text-xs text-gray-500 dark:text-gray-400">${this.escapeHtml(item.name_kana)}</div>` : ''}
      </div>
    `).join('')

    this.showResults()
  }

  selectItem(event) {
    const id = event.currentTarget.dataset.id
    const name = event.currentTarget.dataset.name

    this.personIdTarget.value = id
    this.inputTarget.value = name

    if (this.hasPersonNameTarget && !this.personNameTarget.value) {
      this.personNameTarget.value = name
    }

    this.hideResults()
  }

  clear() {
    this.personIdTarget.value = ''
    this.inputTarget.value = ''
  }

  showResults() {
    this.resultsTarget.classList.remove('hidden')
  }

  hideResults() {
    this.activeIndex = -1
    this.resultsTarget.classList.add('hidden')
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
