import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "selected", "hiddenField"]
  static values = {
    url: String,
    fieldName: String  // "units" or "people"
  }

  connect() {
    this.selectedItems = this.loadExistingItems()
    this.timeout = null
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
    if (items.length === 0) {
      this.hideResults()
      return
    }

    const idField = this.fieldNameValue === 'units' ? 'unit_id' : 'person_id'
    const selectedIds = this.selectedItems.map(item => item[idField])

    this.resultsTarget.innerHTML = items
      .filter(item => !selectedIds.includes(item.id))
      .map(item => `
        <div class="px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer"
             data-action="click->autocomplete#selectItem"
             data-id="${item.id}"
             data-name="${this.escapeHtml(item.name)}">
          <div class="font-medium text-gray-900 dark:text-gray-100">${this.escapeHtml(item.name)}</div>
          ${item.name_kana ? `<div class="text-xs text-gray-500 dark:text-gray-400">${this.escapeHtml(item.name_kana)}</div>` : ''}
        </div>
      `).join('')

    this.showResults()
  }

  selectItem(event) {
    const id = parseInt(event.currentTarget.dataset.id)
    const name = event.currentTarget.dataset.name

    const idField = this.fieldNameValue === 'units' ? 'unit_id' : 'person_id'

    this.selectedItems.push({
      [idField]: id,
      name: name
    })

    this.updateHiddenField()
    this.renderSelectedItems()
    this.inputTarget.value = ''
    this.hideResults()
  }

  removeItem(event) {
    const id = parseInt(event.currentTarget.dataset.id)
    const idField = this.fieldNameValue === 'units' ? 'unit_id' : 'person_id'

    this.selectedItems = this.selectedItems.filter(item => item[idField] !== id)

    this.updateHiddenField()
    this.renderSelectedItems()
  }

  renderSelectedItems() {
    const idField = this.fieldNameValue === 'units' ? 'unit_id' : 'person_id'
    const colorClass = this.fieldNameValue === 'units'
      ? 'bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-200'
      : 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'

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
    this.resultsTarget.classList.add('hidden')
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
