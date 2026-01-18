import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "input"]

  connect() {
    this.toggle()
  }

  toggle() {
    if (this.checkboxTarget.checked && this.inputTarget.value) {
      const date = new Date(this.inputTarget.value)
      if (!isNaN(date.getTime())) {
        // Set year to 1904
        date.setFullYear(1904)
        const year = date.getFullYear()
        const month = String(date.getMonth() + 1).padStart(2, '0')
        const day = String(date.getDate()).padStart(2, '0')
        this.inputTarget.value = `${year}-${month}-${day}`
      }
    }
  }
}
