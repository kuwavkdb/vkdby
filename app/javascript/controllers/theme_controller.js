import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "theme"
const MODES = ["auto", "light", "dark"]
const MODE_LABELS = { auto: "自動", light: "ライト", dark: "ダーク" }

export default class extends Controller {
    static targets = ["iconAuto", "iconLight", "iconDark", "srLabel", "label"]

    connect() {
        this.media = window.matchMedia("(prefers-color-scheme: dark)")
        this.boundApplyTheme = this.applyTheme.bind(this)
        this.media.addEventListener("change", this.boundApplyTheme)
        // ヘッダーとモバイルメニューに複数のトグルがあるため、他方の切り替えにも追従する
        document.addEventListener("theme:changed", this.boundApplyTheme)
        this.applyTheme()
    }

    disconnect() {
        this.media.removeEventListener("change", this.boundApplyTheme)
        document.removeEventListener("theme:changed", this.boundApplyTheme)
    }

    toggle() {
        const nextMode = MODES[(MODES.indexOf(this.currentMode()) + 1) % MODES.length]
        try {
            localStorage.setItem(STORAGE_KEY, nextMode)
        } catch (e) {}
        document.dispatchEvent(new CustomEvent("theme:changed"))
    }

    applyTheme() {
        const mode = this.currentMode()
        const dark = mode === "dark" || (mode === "auto" && this.media.matches)
        document.documentElement.classList.toggle("dark", dark)

        this.iconAutoTarget.classList.toggle("hidden", mode !== "auto")
        this.iconLightTarget.classList.toggle("hidden", mode !== "light")
        this.iconDarkTarget.classList.toggle("hidden", mode !== "dark")

        const nextMode = MODES[(MODES.indexOf(mode) + 1) % MODES.length]
        this.srLabelTarget.textContent = `テーマ: ${MODE_LABELS[mode]}（クリックで${MODE_LABELS[nextMode]}に切り替え）`
        if (this.hasLabelTarget) this.labelTarget.textContent = `テーマ: ${MODE_LABELS[mode]}`
    }

    currentMode() {
        try {
            const mode = localStorage.getItem(STORAGE_KEY)
            return MODES.includes(mode) ? mode : "auto"
        } catch (e) {
            return "auto"
        }
    }
}
