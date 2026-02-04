import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["menu", "button"]
    static values = { open: Boolean }

    connect() {
        if (this.openValue) {
            this.show()
        } else {
            this.hide()
        }
    }

    toggle(event) {
        this.openValue = !this.openValue
    }

    openValueChanged() {
        if (this.openValue) {
            this.show()
        } else {
            this.hide()
        }
    }

    show() {
        this.menuTarget.classList.remove("hidden")
        this.menuTarget.classList.add("enter-active") // For transitions if needed
        // Rotate icon if exists
        const icon = this.buttonTarget.querySelector("svg")
        if (icon) icon.classList.add("rotate-180")
    }

    hide(event) {
        if (event && (this.element.contains(event.target))) {
            return
        }
        this.openValue = false
        this.menuTarget.classList.add("hidden")

        const icon = this.buttonTarget.querySelector("svg")
        if (icon) icon.classList.remove("rotate-180")
    }
}
