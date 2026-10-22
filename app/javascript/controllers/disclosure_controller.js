import { Controller } from "@hotwired/stimulus"

// ボタンで、離れた場所にある欄を開閉する。開閉状態は aria-expanded に反映する（issue #1921）
export default class extends Controller {
    static targets = ["button", "panel"]

    toggle() {
        const open = this.buttonTarget.getAttribute("aria-expanded") !== "true"
        this.buttonTarget.setAttribute("aria-expanded", String(open))
        this.panelTarget.hidden = !open
    }
}
