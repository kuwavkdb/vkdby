import { Controller } from "@hotwired/stimulus"

// IndexGroup 単位のタグをインクリメンタル検索して選択するコンボボックス。
// 選択すると、現在のURLの他のパラメータ（status, q など）は保持したまま
// tag_index_id だけを差し替えて一覧ページへ遷移する。
export default class extends Controller {
  static targets = ["input", "results"]
  static values = {
    tags: Array
  }

  connect() {
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
    const query = this.inputTarget.value.trim().toLowerCase()
    const filtered = query
      ? this.tagsValue.filter(tag => tag.name.toLowerCase().includes(query))
      : this.tagsValue

    this.displayResults(filtered)
  }

  onKeydown(event) {
    const items = this.resultItems

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        if (this.resultsTarget.classList.contains('hidden')) {
          this.search()
          return
        }
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

  displayResults(items) {
    this.activeIndex = -1

    if (items.length === 0) {
      this.resultsTarget.innerHTML = `<div class="px-4 py-2 text-sm text-gray-400 dark:text-gray-500">該当するタグがありません</div>`
    } else {
      this.resultsTarget.innerHTML = items.map(tag => `
        <div class="px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer text-sm text-gray-900 dark:text-gray-100"
             role="option"
             data-action="click->tag-group-select#selectItem"
             data-id="${tag.id}">
          ${this.escapeHtml(tag.name)}
        </div>
      `).join('')
    }

    this.showResults()
  }

  selectItem(event) {
    const id = event.currentTarget.dataset.id
    const url = new URL(window.location.href)
    url.searchParams.set('tag_index_id', id)
    window.location.href = url.toString()
  }

  showResults() {
    this.resultsTarget.classList.remove('hidden')
    this.inputTarget.setAttribute('aria-expanded', 'true')
  }

  hideResults() {
    this.activeIndex = -1
    this.resultsTarget.classList.add('hidden')
    this.inputTarget.setAttribute('aria-expanded', 'false')
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
