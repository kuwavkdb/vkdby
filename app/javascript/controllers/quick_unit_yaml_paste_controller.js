import { Controller } from "@hotwired/stimulus"
import { application } from "controllers/application"

// Unit簡単登録フォーム（quick_new）の「YAMLから一括入力」欄（issue #1620）。
// unit-url スキル等が出力したYAMLをパースし、同じ画面内の quick-unit-form コントローラーへ
// 委譲してフォームの各欄に反映する。あくまで入力補助であり、保存やバリデーションは行わない。
export default class extends Controller {
  static targets = ["textarea", "error", "success"]

  async apply() {
    this.hideMessages()

    const text = this.textareaTarget.value.trim()
    if (!text) {
      this.showError("YAMLを貼り付けてください。")
      return
    }

    let data
    try {
      const yaml = await import("js-yaml")
      data = yaml.load(text)
    } catch (e) {
      this.showError(`YAMLの読み込みに失敗しました: ${e.message}`)
      return
    }

    if (data == null || typeof data !== "object" || Array.isArray(data)) {
      this.showError("YAMLの形式が不正です（トップレベルはマッピングである必要があります）。")
      return
    }

    const formController = this.findFormController()
    if (!formController) {
      this.showError("フォームが見つかりませんでした。ページを再読み込みしてください。")
      return
    }

    try {
      formController.applyData(data)
    } catch (e) {
      this.showError(`フォームへの反映に失敗しました: ${e.message}`)
      return
    }

    this.showSuccess("フォームに反映しました。内容を確認してください。")
  }

  findFormController() {
    const el = document.querySelector('[data-controller~="quick-unit-form"]')
    if (!el) return null
    return application.getControllerForElementAndIdentifier(el, "quick-unit-form")
  }

  hideMessages() {
    this.errorTarget.classList.add("hidden")
    this.successTarget.classList.add("hidden")
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
    this.successTarget.classList.add("hidden")
  }

  showSuccess(message) {
    this.successTarget.textContent = message
    this.successTarget.classList.remove("hidden")
    this.errorTarget.classList.add("hidden")
  }
}
