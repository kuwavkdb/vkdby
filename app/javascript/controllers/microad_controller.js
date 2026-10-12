import { Controller } from "@hotwired/stimulus"

// MicroAd の広告枠（layouts/_microad）で、広告が実際に入ったときだけ「広告」の表記と囲みを出す（issue #1837）。
// 未配信のまま「広告」の文字だけが残ると、近くにある販売サイトへの導線が広告の中身のように見えてしまうため。
// 広告タグの <script> 以外の要素が高さを持って枠に入ったら配信されたとみなし、要素に data-filled を付ける。
// 見た目の切り替えは data-filled を見る Tailwind の data-filled: / group-data-filled: で行う。
export default class extends Controller {
    static targets = ["slot"]

    connect() {
        if (this.markFilledIfRendered()) return

        this.observer = new MutationObserver(() => this.markFilledIfRendered())
        this.observer.observe(this.slotTarget, { childList: true, subtree: true, attributes: true })
    }

    disconnect() {
        this.observer?.disconnect()
    }

    markFilledIfRendered() {
        const rendered = Array.from(this.slotTarget.querySelectorAll("*"))
            .some((el) => el.tagName !== "SCRIPT" && el.offsetHeight > 0)
        if (!rendered) return false

        this.element.dataset.filled = ""
        this.observer?.disconnect()
        return true
    }
}
