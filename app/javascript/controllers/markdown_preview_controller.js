import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"

export default class extends Controller {
  static targets = ["textarea", "previewContent"]

  connect() {
    marked.use({ breaks: true, gfm: true })
    this.updatePreview()
  }

  updatePreview() {
    const text = this.textareaTarget.value
    this.previewContentTarget.innerHTML = text
      ? marked.parse(text)
      : '<p class="text-gray-400 dark:text-gray-500 italic">本文を入力するとプレビューが表示されます</p>'
  }
}
