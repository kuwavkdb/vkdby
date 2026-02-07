import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["menu", "iconOpen", "iconClose"]

    connect() {
        console.log("MobileMenuController connected")
        this.close()
    }

    toggle(event) {
        if (event) event.preventDefault()
        console.log("MobileMenuController toggle clicked")
        if (this.menuTarget.classList.contains("hidden")) {
            this.open()
        } else {
            this.close()
        }
    }

    open() {
        this.menuTarget.classList.remove("hidden")
        this.element.setAttribute("aria-expanded", "true")
        if (this.hasIconOpenTarget) this.iconOpenTarget.classList.add("hidden")
        if (this.hasIconCloseTarget) this.iconCloseTarget.classList.remove("hidden")
    }

    close() {
        this.menuTarget.classList.add("hidden")
        this.element.setAttribute("aria-expanded", "false")
        if (this.hasIconOpenTarget) this.iconOpenTarget.classList.remove("hidden")
        if (this.hasIconCloseTarget) this.iconCloseTarget.classList.add("hidden")
    }
}
