import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["menu", "iconOpen", "iconClose"]

    connect() {
        console.log("MobileMenuController connected")
        this.close()

        // メニュー外クリックで閉じる
        this.boundHandleClickOutside = this.handleClickOutside.bind(this)
        document.addEventListener("click", this.boundHandleClickOutside)

        // 他のメニューが開いたら自分を閉じる
        this.boundHandleOtherMenuOpened = this.handleOtherMenuOpened.bind(this)
        document.addEventListener("mobile-menu:opened", this.boundHandleOtherMenuOpened)
    }

    disconnect() {
        document.removeEventListener("click", this.boundHandleClickOutside)
        document.removeEventListener("mobile-menu:opened", this.boundHandleOtherMenuOpened)
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

        // 他のメニューに通知
        const event = new CustomEvent("mobile-menu:opened", {
            detail: { controller: this }
        })
        document.dispatchEvent(event)
    }

    close() {
        this.menuTarget.classList.add("hidden")
        this.element.setAttribute("aria-expanded", "false")
        if (this.hasIconOpenTarget) this.iconOpenTarget.classList.remove("hidden")
        if (this.hasIconCloseTarget) this.iconCloseTarget.classList.add("hidden")
    }

    handleClickOutside(event) {
        // メニューが閉じている場合は何もしない
        if (this.menuTarget.classList.contains("hidden")) return

        // クリックがメニュー内またはボタン内の場合は何もしない
        if (this.element.contains(event.target) || this.menuTarget.contains(event.target)) {
            return
        }

        // メニュー外のクリックなので閉じる
        this.close()
    }

    handleOtherMenuOpened(event) {
        // 自分自身が開いたイベントの場合は無視
        if (event.detail.controller === this) return

        // 他のメニューが開いたので自分を閉じる
        this.close()
    }
}
