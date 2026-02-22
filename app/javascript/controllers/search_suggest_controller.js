import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "suggestions"]
  static values = {
    url: String
  }

  connect() {
    this.timeout = null
    this.activeIndex = -1
    this.handleClickOutside = this.handleClickOutside.bind(this)
    this.handleReposition = this.reposition.bind(this)
    this.handleScroll = this.hideSuggestions.bind(this)
    document.addEventListener('click', this.handleClickOutside)
    window.addEventListener('resize', this.handleReposition)
    window.addEventListener('scroll', this.handleScroll, true)
  }

  disconnect() {
    document.removeEventListener('click', this.handleClickOutside)
    window.removeEventListener('resize', this.handleReposition)
    window.removeEventListener('scroll', this.handleScroll, true)
    clearTimeout(this.timeout)
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideSuggestions()
    }
  }

  reposition() {
    const rect = this.inputTarget.getBoundingClientRect()
    // position: fixed なので viewport 相対座標をそのまま使う
    this.suggestionsTarget.style.top = `${rect.bottom + 4}px`
    this.suggestionsTarget.style.left = `${rect.left}px`
    this.suggestionsTarget.style.width = `${rect.width}px`
  }

  onInput() {
    clearTimeout(this.timeout)
    const query = this.inputTarget.value.trim()

    if (query.length < 2) {
      this.hideSuggestions()
      return
    }

    this.timeout = setTimeout(() => {
      this.fetchSuggestions(query)
    }, 300)
  }

  onKeydown(event) {
    if (this.suggestionsTarget.classList.contains('hidden')) return

    const items = this.suggestionItems

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        this.activeIndex = Math.min(this.activeIndex + 1, items.length - 1)
        this.highlightItem(items)
        break
      case 'ArrowUp':
        event.preventDefault()
        this.activeIndex = Math.max(this.activeIndex - 1, 0)
        this.highlightItem(items)
        break
      case 'Enter':
        if (this.activeIndex >= 0 && items[this.activeIndex]) {
          event.preventDefault()
          window.location.href = items[this.activeIndex].href
        }
        break
      case 'Escape':
        this.hideSuggestions()
        break
    }
  }

  get suggestionItems() {
    return Array.from(this.suggestionsTarget.querySelectorAll('[data-key]'))
  }

  highlightItem(items) {
    items.forEach((item, index) => {
      item.classList.toggle('bg-slate-100', index === this.activeIndex)
      item.classList.toggle('dark:bg-slate-700', index === this.activeIndex)
    })
    if (items[this.activeIndex]) {
      items[this.activeIndex].scrollIntoView({ block: 'nearest' })
    }
  }

  async fetchSuggestions(query) {
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: { 'Accept': 'application/json' }
      })
      if (!response.ok) throw new Error('Search failed')
      const data = await response.json()
      this.renderSuggestions(data)
    } catch (error) {
      console.error('SearchSuggest error:', error)
    }
  }

  renderSuggestions(items) {
    this.activeIndex = -1

    if (items.length === 0) {
      this.hideSuggestions()
      return
    }

    this.suggestionsTarget.innerHTML = items.map(item => `
      <a href="/${this.escapeHtml(item.key)}"
         data-key="${this.escapeHtml(item.key)}"
         class="flex items-baseline gap-2 px-4 py-2 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors">
        <span class="font-medium text-slate-800 dark:text-slate-100">${this.escapeHtml(item.name)}</span>
        ${item.name_kana ? `<span class="text-xs text-slate-400 dark:text-slate-500 truncate">${this.escapeHtml(item.name_kana)}</span>` : ''}
      </a>
    `).join('')

    this.reposition()
    this.suggestionsTarget.classList.remove('hidden')
  }

  hideSuggestions() {
    this.activeIndex = -1
    this.suggestionsTarget.classList.add('hidden')
    this.suggestionsTarget.innerHTML = ''
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
