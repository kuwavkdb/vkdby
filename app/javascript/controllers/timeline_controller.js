import { Controller } from "@hotwired/stimulus"

// 横スクロールをヘッダ行とデータ行で同期する
export default class extends Controller {
  static targets = ["header", "body"]

  syncHeader() {
    this.headerTarget.scrollLeft = this.bodyTarget.scrollLeft
  }
}
