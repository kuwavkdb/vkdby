import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "previewContent", "imageInput", "uploadStatus", "previewStatus"]
  static values = { uploadUrl: String, previewUrl: String, customPageId: String }

  async connect() {
    const { marked } = await import("marked")
    this._marked = marked
    this._marked.use({ breaks: true, gfm: true })
    this.updatePreview()
  }

  updatePreview() {
    const text = this.textareaTarget.value
    this.previewContentTarget.innerHTML = text && this._marked
      ? this._marked.parse(text)
      : '<p class="text-gray-400 dark:text-gray-500 italic">本文を入力するとプレビューが表示されます</p>'
    this.#setPreviewStatus("")
  }

  // {{include}}/{{snapshot}}/{{item}} 等のプラグイン記法を含め、実際の公開ページと
  // 同じサーバーサイドレンダリングでプレビューする（issue #1089）。
  // 本文を編集すると input イベントで updatePreview が呼ばれ、通常のクライアント側
  // プレビューに自動的に戻る。
  async serverPreview() {
    if (!this.hasPreviewUrlValue) return

    this.#setPreviewStatus("サーバーでレンダリング中...")

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const formData = new FormData()
    formData.append("body", this.textareaTarget.value)
    if (this.hasCustomPageIdValue && this.customPageIdValue) {
      formData.append("id", this.customPageIdValue)
    }

    try {
      const response = await fetch(this.previewUrlValue, {
        method: "POST",
        headers: { "X-CSRF-Token": csrfToken },
        body: formData
      })

      if (!response.ok) throw new Error("Preview failed")

      const data = await response.json()
      this.previewContentTarget.innerHTML = data.html
        || '<p class="text-gray-400 dark:text-gray-500 italic">本文を入力するとプレビューが表示されます</p>'
      this.#setPreviewStatus("サーバーでの実際の描画結果です（編集すると通常のプレビューに戻ります）")
    } catch {
      this.#setPreviewStatus("プレビューの取得に失敗しました", 5000)
    }
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

  #setPreviewStatus(message, clearAfterMs = null) {
    if (this.hasPreviewStatusTarget) {
      this.previewStatusTarget.textContent = message
      if (clearAfterMs) {
        setTimeout(() => { this.previewStatusTarget.textContent = "" }, clearAfterMs)
      }
    }
  }
}
