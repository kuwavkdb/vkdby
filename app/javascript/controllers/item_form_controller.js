import { Controller } from "@hotwired/stimulus"

const AMAZON_URL_BASE = "https://www.amazon.co.jp/exec/obidos/ASIN/"
const AMAZON_URL_SUFFIX = "/vkdb-22/"

export default class extends Controller {
  static targets = ["asin", "linkUrl"]

  autofillLinkUrl() {
    if (this.linkUrlTarget.value.trim() !== "") return

    const asin = this.asinTarget.value.trim()
    if (asin === "") return

    this.linkUrlTarget.value = `${AMAZON_URL_BASE}${asin}${AMAZON_URL_SUFFIX}`
  }

  // ASIN重複エラー時に表示される「上書きして保存」ボタン用（issue #1509）。
  // 本来はcreateアクション（POST /admin/items）へ送信されるフォームを、
  // 既存アイテムのupdateアクション（PATCH /admin/items/:id）へ送信し直すことで、
  // 入力済みの内容をそのまま既存アイテムへ上書き保存できるようにする。
  overwriteExisting(event) {
    const button = event.currentTarget
    const url = button.dataset.overwriteUrl
    if (!url) return

    const title = button.dataset.overwriteTitle || ""
    if (!window.confirm(`「${title}」の内容をこのフォームの内容で上書きしますか？`)) {
      event.preventDefault()
      return
    }

    this.element.action = url

    let methodInput = this.element.querySelector('input[name="_method"]')
    if (!methodInput) {
      methodInput = document.createElement("input")
      methodInput.type = "hidden"
      methodInput.name = "_method"
      this.element.appendChild(methodInput)
    }
    methodInput.value = "patch"
  }
}
