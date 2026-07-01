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
}
