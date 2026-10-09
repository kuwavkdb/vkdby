import { Controller } from "@hotwired/stimulus"

// エリアの入力欄に、選んだ都道府県の既存のエリアを候補（datalist）として出す（issue #1814）。
// areas は { 都道府県: [エリア, ...] }。都道府県を変えると候補を入れ替える
export default class extends Controller {
  static targets = ["prefecture", "options"]
  static values = { areas: Object }

  connect() {
    this.update()
  }

  update() {
    const areas = this.areasValue[this.prefectureTarget.value] || []
    this.optionsTarget.replaceChildren(...areas.map((area) => {
      const option = document.createElement("option")
      option.value = area
      return option
    }))
  }
}
