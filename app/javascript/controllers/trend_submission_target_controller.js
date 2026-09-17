import { Controller } from "@hotwired/stimulus"

// 汎用エントリーポイント（対象を投稿者が選ぶ場合）で、対象種別(ユニット/個人)の
// ラジオボタンの選択に応じて対応する動向種別セレクトのみを表示・送信可能にする
// （issue #1553: unit_phenomenon / person_phenomenonを同時に出さない）
export default class extends Controller {
  static targets = ["typeRadio", "unitPhenomenon", "personPhenomenon"]

  connect() {
    this.sync()
  }

  sync() {
    const checked = this.typeRadioTargets.find((radio) => radio.checked)
    const isUnit = !checked || checked.value === "unit"

    this.applyState(this.unitPhenomenonTargets, isUnit)
    this.applyState(this.personPhenomenonTargets, !isUnit)
  }

  applyState(targets, visible) {
    targets.forEach((el) => {
      el.classList.toggle("hidden", !visible)
      el.querySelectorAll("select, input").forEach((field) => {
        field.disabled = !visible
      })
    })
  }
}
