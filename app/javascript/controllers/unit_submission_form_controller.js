import { Controller } from "@hotwired/stimulus"

// ユニット投稿フォームで、本人・関係者のチェックに合わせて画像欄を表示・送信可能にする
// （issue #1718）。連動していることは案内しないため、表示の切り替えにアニメーションは付けない。
// チェックを外したときは、選んだファイルと利用の了承もクリアする
export default class extends Controller {
  static targets = ["relatedPerson", "images"]

  connect() {
    this.sync()
  }

  sync() {
    const enabled = this.relatedPersonTarget.checked

    this.imagesTargets.forEach((fieldset) => {
      fieldset.classList.toggle("hidden", !enabled)
      fieldset.disabled = !enabled
      if (enabled) return

      fieldset.querySelectorAll("input[type=file]").forEach((input) => { input.value = "" })
      fieldset.querySelectorAll("input[type=checkbox]").forEach((input) => { input.checked = false })
    })
  }
}
