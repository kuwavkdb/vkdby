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
        this.enter()

        // Rotate icon if exists
        const icon = this.buttonTarget.querySelector("svg")
        if (icon) icon.classList.add("rotate-180")
    }

    hide(event) {
        if (event && (this.element.contains(event.target))) {
            return
        }

        // If called from event (click outside), update state which triggers openValueChanged -> hide()
        if (this.openValue) {
            this.openValue = false
            return
        }

        this.leave()

        const icon = this.buttonTarget.querySelector("svg")
        if (icon) icon.classList.remove("rotate-180")
    }

    enter() {
        const element = this.menuTarget
        const enterClasses = this.getClasses("transitionEnter")
        const enterStartClasses = this.getClasses("transitionEnterStart")
        const enterEndClasses = this.getClasses("transitionEnterEnd")

        element.classList.add(...enterClasses)
        element.classList.add(...enterStartClasses)
        element.classList.remove(...enterEndClasses)

        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                element.classList.remove(...enterStartClasses)
                element.classList.add(...enterEndClasses)

                element.addEventListener("transitionend", () => {
                    element.classList.remove(...enterClasses)
                }, { once: true })
            })
        })
    }

    leave() {
        const element = this.menuTarget
        const leaveClasses = this.getClasses("transitionLeave")
        const leaveStartClasses = this.getClasses("transitionLeaveStart")
        const leaveEndClasses = this.getClasses("transitionLeaveEnd")

        element.classList.add(...leaveClasses)
        element.classList.add(...leaveStartClasses)
        element.classList.remove(...leaveEndClasses)

        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                element.classList.remove(...leaveStartClasses)
                element.classList.add(...leaveEndClasses)

                element.addEventListener("transitionend", () => {
                    if (!this.openValue) {
                        element.classList.add("hidden")
                    }
                    element.classList.remove(...leaveClasses)
                    element.classList.remove(...leaveEndClasses)
                }, { once: true })
            })
        })
    }

    getClasses(name) {
        return (this.menuTarget.dataset[name] || "").split(" ").filter(c => c.length > 0)
    }
}
