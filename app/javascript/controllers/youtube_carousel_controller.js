import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["slide", "dot"]
    static values = { index: { type: Number, default: 0 } }

    indexValueChanged() {
        this.slideTargets.forEach((el, i) => {
            el.classList.toggle("hidden", i !== this.indexValue)
        })

        this.dotTargets.forEach((el, i) => {
            const active = i === this.indexValue
            el.classList.toggle("bg-slate-800", active)
            el.classList.toggle("dark:bg-slate-200", active)
            el.classList.toggle("bg-slate-300", !active)
            el.classList.toggle("dark:bg-slate-600", !active)
            el.setAttribute("aria-current", active ? "true" : "false")
        })
    }

    select(event) {
        this.indexValue = Number(event.params.index)
    }
}
