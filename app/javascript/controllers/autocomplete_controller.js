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
    return Array.from(this.resultsTarget.querySelectorAll('[data-id], [data-unregistered]'))
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
      this.displayResults(data, query)
    } catch (error) {
      console.error('Autocomplete error:', error)
    }
  }

  displayResults(items, query) {
    this.activeIndex = -1

    const idField = this.fieldNameValue === 'people' ? 'person_id' : 'unit_id'
    const selectedIds = this.selectedItems
      .filter(item => item[idField] != null)
      .map(item => item[idField])

    const filtered = items.filter(item => !selectedIds.includes(item.id))

    const isUnitsField = this.fieldNameValue === 'units'
    const currentQuery = query || this.inputTarget.value.trim()

    // units フィールドの場合、既に同名の未登録アイテムが追加済みか確認
    const alreadyAddedAsUnregistered = isUnitsField &&
      this.selectedItems.some(item => item.unit_id == null && item.name === currentQuery)

    const showUnregisteredOption = isUnitsField && currentQuery.length >= 2 && !alreadyAddedAsUnregistered

    if (filtered.length === 0 && !showUnregisteredOption) {
      this.hideResults()
      return
    }

    const registeredHtml = filtered
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

    const unregisteredHtml = showUnregisteredOption
      ? `<div class="px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer border-t border-gray-100 dark:border-gray-700"
               data-action="click->autocomplete#addUnregisteredItem"
               data-unregistered="true"
               data-name="${this.escapeHtml(currentQuery)}">
            <div class="text-sm text-gray-500 dark:text-gray-400">「${this.escapeHtml(currentQuery)}」を未登録として追加</div>
          </div>`
      : ''

    this.resultsTarget.innerHTML = registeredHtml + unregisteredHtml
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

  addUnregisteredItem(event) {
    const name = event.currentTarget.dataset.name
    if (!name) return

    this.selectedItems.push({ name })
    this.updateHiddenField()
    this.renderSelectedItems()
    this.inputTarget.value = ''
    this.hideResults()
  }

  removeItem(event) {
    const el = event.currentTarget

    if (el.dataset.unregistered) {
      const name = el.dataset.name
      this.selectedItems = this.selectedItems.filter(item =>
        !(item.unit_id == null && item.name === name)
      )
    } else {
      const id = parseInt(el.dataset.id)
      const idField = this.fieldNameValue === 'people' ? 'person_id' : 'unit_id'
      this.selectedItems = this.selectedItems.filter(item => item[idField] !== id)
    }

    this.updateHiddenField()
    this.renderSelectedItems()
  }

  renderSelectedItems() {
    const idField = this.fieldNameValue === 'people' ? 'person_id' : 'unit_id'
    const colorClass = this.fieldNameValue === 'people'
      ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
      : 'bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-200'

    this.selectedTarget.innerHTML = this.selectedItems.map(item => {
      const isUnregistered = item[idField] == null
      const removeAttrs = isUnregistered
        ? `data-unregistered="true" data-name="${this.escapeHtml(item.name)}"`
        : `data-id="${item[idField]}"`
      const label = isUnregistered
        ? `${this.escapeHtml(item.name)}<span class="ml-1 text-xs opacity-60">(未登録)</span>`
        : this.escapeHtml(item.name)

      return `
        <span class="inline-flex items-center px-3 py-1 rounded-full text-sm ${colorClass}">
          ${label}
          <button type="button"
                  data-action="click->autocomplete#removeItem"
                  ${removeAttrs}
                  class="ml-2 hover:opacity-75">×</button>
        </span>
      `
    }).join('')
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
