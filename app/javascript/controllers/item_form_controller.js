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

  // ASIN重複エラー時に表示される「編集画面で確認する」ボタン用（issue #1509, #1515）。
  // 本来はcreateアクション（POST /admin/items）へ送信されるフォームを、
  // methodをgetに変えて既存アイテムのeditアクションへ送信し直すことで、
  // 入力済みの内容をクエリパラメータ（item[...]）として編集画面に引き継ぐ。
  //
  // 以前はJSでaction/methodをPATCHに書き換えてその場で送信し直していたが、
  // フォームのauthenticity_tokenはPOST /admin/items専用に生成されている
  // （per_form_csrf_tokens）ため、送信先を書き換えるとCSRF検証に失敗していた
  // （本番でのみ発覚。test環境はallow_forgery_protection=falseのため検出できず）。
  // GET遷移はCSRF検証の対象外なのでこの問題が起きず、かつ編集画面側で
  // 上書き内容を確認してから改めて「更新」を押す一手間を挟めるため安全になる。
  overwriteExisting(event) {
    const url = event.currentTarget.dataset.overwriteUrl
    if (!url) return

    // アーティストは上書き対象から除外する（issue #1515）。既存アイテム側の
    // アーティスト行と衝突して編集画面側が空になってしまうため、
    // item[artists_json]はこのGET遷移には含めない（disabledにすると送信されない）。
    const artistsJsonInput = this.element.querySelector('input[name="item[artists_json]"]')
    if (artistsJsonInput) artistsJsonInput.disabled = true

    this.element.method = "get"
    this.element.action = url
  }
}
