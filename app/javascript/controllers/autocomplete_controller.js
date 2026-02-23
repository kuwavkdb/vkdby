import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "selected", "hiddenField"]
  static values = {
    url: String,
    fieldName: String  // "units", "people", or "artists"
  }

  connect() {
    this.selectedItems = this.loadExistingItems()
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

  loadExistingItems() {
    try {
      const data = JSON.parse(this.hiddenFieldTarget.value || '[]')
      return data
    } catch (e) {
      return []
    }
  }

  search() {
    clearTimeout(this.timeout)

    const query = this.inputTarget.value.trim()

    if (query.length < 2) {
      this.hideResults()
      return
    }

    this.timeout = setTimeout(() => {
      this.performSearch(query)
    }, 300) // Debounce 300ms
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
      console.error('Autocomplete error:', error)
    }
  }

  displayResults(items) {
    this.activeIndex = -1

    if (items.length === 0) {
      this.hideResults()
      return
    }

    const idField = this.fieldNameValue === 'people' ? 'person_id' : 'unit_id'
    const selectedIds = this.selectedItems.map(item => item[idField])

    const filtered = items.filter(item => !selectedIds.includes(item.id))

    if (filtered.length === 0) {
      this.hideResults()
      return
    }

    this.resultsTarget.innerHTML = filtered
      .map(item => `
        <div class="px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer"
             data-action="click->autocomplete#selectItem"
             data-id="${item.id}"
             data-name="${this.escapeHtml(item.name)}"
             data-key="${this.escapeHtml(item.key || '')}">
          <div class="font-medium text-gray-900 dark:text-gray-100">${this.escapeHtml(item.name)}</div>
          ${item.name_kana ? `<div class="text-xs text-gray-500 dark:text-gray-400">${this.escapeHtml(item.name_kana)}</div>` : ''}
        </div>
      `).join('')

    this.showResults()
  }

  selectItem(event) {
    const id = parseInt(event.currentTarget.dataset.id)
    const name = event.currentTarget.dataset.name
    const key = event.currentTarget.dataset.key || ''

    if (this.fieldNameValue === 'artists') {
      this.selectedItems.push({ unit_id: id, name, key })
    } else {
      const idField = this.fieldNameValue === 'people' ? 'person_id' : 'unit_id'
      this.selectedItems.push({ [idField]: id, name })
    }

    this.updateHiddenField()
    this.renderSelectedItems()
    this.inputTarget.value = ''
    this.hideResults()
  }

  removeItem(event) {
    const id = parseInt(event.currentTarget.dataset.id)
    const idField = this.fieldNameValue === 'people' ? 'person_id' : 'unit_id'

    this.selectedItems = this.selectedItems.filter(item => item[idField] !== id)

    this.updateHiddenField()
    this.renderSelectedItems()
  }

  renderSelectedItems() {
    const idField = this.fieldNameValue === 'people' ? 'person_id' : 'unit_id'
    const colorClass = this.fieldNameValue === 'people'
      ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
      : 'bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-200'

    this.selectedTarget.innerHTML = this.selectedItems.map(item => `
      <span class="inline-flex items-center px-3 py-1 rounded-full text-sm ${colorClass}">
        ${this.escapeHtml(item.name)}
        <button type="button"
                data-action="click->autocomplete#removeItem"
                data-id="${item[idField]}"
                class="ml-2 hover:opacity-75">×</button>
      </span>
    `).join('')
  }

  updateHiddenField() {
    this.hiddenFieldTarget.value = JSON.stringify(this.selectedItems)
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
