import { Controller } from "@hotwired/stimulus"

// ユニット名で検索して、対象テキストエリアのカーソル位置に
// Markdownリンク形式（[表示名](/key)）を挿入する（issue #1644）。
// キー操作・検索まわりのUXはunit_select_controller.jsを踏襲する。
export default class extends Controller {
  static targets = ["panel", "input", "results", "textarea"]
  static values = { url: String }

  connect() {
    this.timeout = null
    this.activeIndex = -1
    this.savedPosition = null
    this.handleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener('click', this.handleClickOutside)
  }

  disconnect() {
    document.removeEventListener('click', this.handleClickOutside)
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.closePanel()
    }
  }

  // テキストエリアからフォーカスが外れる瞬間の位置を、挿入位置として記憶する。
  // 一度もフォーカスされていなければsavedPositionはnullのままとなり、
  // insertLinkでテキスト末尾扱いになる。
  rememberPosition() {
    this.savedPosition = this.textareaTarget.selectionStart
  }

  toggle() {
    if (this.panelTarget.classList.contains('hidden')) {
      this.openPanel()
    } else {
      this.closePanel()
    }
  }

  openPanel() {
    this.inputTarget.value = ''
    this.hideResults()
    this.panelTarget.classList.remove('hidden')
    this.inputTarget.focus()
  }

  closePanel() {
    this.panelTarget.classList.add('hidden')
    this.hideResults()
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
        this.closePanel()
        this.textareaTarget.focus()
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
      console.error('Unit link insert error:', error)
    }
  }

  displayResults(items) {
    this.activeIndex = -1

    if (items.length === 0) {
      this.hideResults()
      return
    }

    // destination_keyが設定されている（統合・改名によるリダイレクト元でない、
    // 現行の「移動先」を持つ）ユニットの場合は、リダイレクトを経由しない
    // destination_key側のURLを挿入する。
    this.resultsTarget.innerHTML = items.map(item => `
      <div class="px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer"
           data-action="click->unit-link-insert#selectItem"
           data-id="${item.id}"
           data-name="${this.escapeHtml(item.name)}"
           data-key="${this.escapeHtml(item.destination_key || item.key)}">
        <div class="font-medium text-gray-900 dark:text-gray-100">${this.escapeHtml(item.name)}</div>
        ${item.key ? `<div class="text-xs text-gray-500 dark:text-gray-400 font-mono">${this.escapeHtml(item.key)}</div>` : ''}
      </div>
    `).join('')

    this.showResults()
  }

  selectItem(event) {
    const name = event.currentTarget.dataset.name
    const key = event.currentTarget.dataset.key

    this.insertLink(name, key)
    this.closePanel()
  }

  insertLink(name, key) {
    const textarea = this.textareaTarget
    const insertion = `[${name}](/${key})`
    const position = this.savedPosition ?? textarea.value.length

    textarea.value = textarea.value.slice(0, position) + insertion + textarea.value.slice(position)

    const newPosition = position + insertion.length
    textarea.selectionStart = textarea.selectionEnd = newPosition
    this.savedPosition = newPosition
    textarea.dispatchEvent(new Event('input'))
    textarea.focus()
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
