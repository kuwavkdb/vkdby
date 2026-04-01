import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"

export default class extends Controller {
  static targets = ["textarea", "previewContent", "imageInput", "uploadStatus"]
  static values = { uploadUrl: String }

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

  selectImage() {
    this.imageInputTarget.click()
  }

  async uploadImage(event) {
    const file = event.target.files[0]
    if (!file) return

    this.#setStatus("アップロード中...")

    const formData = new FormData()
    formData.append("image", file)

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.uploadUrlValue, {
        method: "POST",
        headers: { "X-CSRF-Token": csrfToken },
        body: formData
      })

      if (!response.ok) throw new Error("Upload failed")

      const data = await response.json()
      this.#insertImageMarkdown(data.url, file.name)
      this.#setStatus("アップロード完了", 3000)
    } catch {
      this.#setStatus("アップロードに失敗しました", 5000)
    } finally {
      event.target.value = ""
    }
  }

  #insertImageMarkdown(url, alt = "") {
    const textarea = this.textareaTarget
    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const insertion = `![${alt}](${url})`

    textarea.value = textarea.value.slice(0, start) + insertion + textarea.value.slice(end)
    textarea.selectionStart = textarea.selectionEnd = start + insertion.length
    textarea.dispatchEvent(new Event("input"))
    textarea.focus()
  }

  #setStatus(message, clearAfterMs = null) {
    if (this.hasUploadStatusTarget) {
      this.uploadStatusTarget.textContent = message
      if (clearAfterMs) {
        setTimeout(() => { this.uploadStatusTarget.textContent = "" }, clearAfterMs)
      }
    }
  }
}
