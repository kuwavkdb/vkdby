import { Controller } from "@hotwired/stimulus"

// 長い文を数行（line-clamp-6）で切って出し、ボタンで全文を開閉する（issue #2095）。
// 管理画面の投稿一覧で、内容が長い投稿の行が大きくなりすぎるのを防ぐ。
// 実際に切れていない（6行に収まっている）ときは、切るのをやめてボタンを隠す
export default class extends Controller {
    static targets = ["content", "button"]

    connect() {
        if (this.contentTarget.scrollHeight <= this.contentTarget.clientHeight + 1) {
            this.contentTarget.classList.remove("line-clamp-6")
            this.buttonTarget.hidden = true
        }
    }

    toggle() {
        const open = this.buttonTarget.getAttribute("aria-expanded") !== "true"
        this.buttonTarget.setAttribute("aria-expanded", String(open))
        this.contentTarget.classList.toggle("line-clamp-6", !open)
        this.buttonTarget.textContent = open ? "閉じる" : "全文を表示"
    }
}
