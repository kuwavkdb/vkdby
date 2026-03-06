import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["content", "icon", "area", "summary"]
    static values = { open: Boolean }

    connect() {
        this.contentTargets.forEach(el => {
            el.style.transition = "max-height 0.3s ease, opacity 0.3s ease, margin 0.3s ease"
            el.style.overflow = "hidden"
        })
        // Apply initial state without animation
        this.applyState(false)
    }

    openValueChanged() {
        if (this.element.isConnected) {
            this.applyState(true)
            if (this.openValue) {
                this.dispatch('opened')
            }
        }
    }

    contentTargetConnected(el) {
        el.style.transition = "max-height 0.3s ease, opacity 0.3s ease, margin 0.3s ease"
        el.style.overflow = "hidden"
        if (!this.openValue) {
            el.style.maxHeight = "0px"
            el.style.opacity = "0"
            el.style.marginTop = "0px"
        }
    }

    applyState(animate) {
        this.contentTargets.forEach(el => {
            if (!animate) {
                el.style.transition = "none"
            }

            if (this.openValue) {
                el.style.maxHeight = el.scrollHeight + "px"
                el.style.opacity = "1"
                el.style.marginTop = ""
                if (animate && el.scrollHeight > 0) {
                    el.addEventListener("transitionend", () => {
                        if (this.openValue) el.style.maxHeight = "none"
                    }, { once: true })
                } else {
                    el.style.maxHeight = "none"
                }
            } else {
                if (el.style.maxHeight === "none") {
                    el.style.maxHeight = el.scrollHeight + "px"
                    el.offsetHeight // eslint-disable-line no-unused-expressions
                }
                el.style.maxHeight = "0px"
                el.style.opacity = "0"
                el.style.marginTop = "0px"
            }

            if (!animate) {
                el.offsetHeight // eslint-disable-line no-unused-expressions
                el.style.transition = "max-height 0.3s ease, opacity 0.3s ease, margin 0.3s ease"
            }
        })

        if (this.hasIconTarget) {
            this.iconTarget.classList.toggle("rotate-180", this.openValue)
        }

        if (this.hasAreaTarget) {
            this.areaTarget.classList.toggle("cursor-pointer", !this.openValue)
        }

        this.summaryTargets.forEach(el => {
            el.classList.toggle("hidden", this.openValue)
        })
    }

    toggle() {
        this.openValue = !this.openValue
    }

    expand() {
        if (!this.openValue) {
            this.openValue = true
        }
    }
}
