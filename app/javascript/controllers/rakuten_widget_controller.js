import { Controller } from "@hotwired/stimulus"

const WIDGET_SRC = "https://xml.affiliate.rakuten.co.jp/widget/js/rakuten_widget.js?20230106"

// document.write はページ全体で1つなので、複数の枠を同時に読み込まないよう順番に処理する
let queue = Promise.resolve()

// 楽天アフィリエイトのウィジェット（layouts/_rakuten_widget）を読み込む（issue #1990）。
// ウィジェットは rakuten_* のグローバル変数を読み、document.write で iframe を書き込む作りになっている。
// Turbo で画面遷移したあと（ページの読み込み完了後）に document.write を呼ぶとページ全体が消えてしまうため、
// 読み込みの間だけ document.write を差し替えて、書き込まれる HTML を枠の中に入れる。
// ページ内容に合わせた商品選択に document.URL が使われるので、srcdoc の iframe には隔離しない。
export default class extends Controller {
    static targets = ["slot"]
    static values = { config: Object, media: String }

    connect() {
        // Turbo のキャッシュから戻ったときに、前回書き込んだ iframe が残っていれば消してから読み込み直す
        this.slotTarget.replaceChildren()
        delete this.element.dataset.filled

        if (this.mediaValue && !window.matchMedia(this.mediaValue).matches) return

        queue = queue.then(() => this.load())
    }

    load() {
        if (!this.element.isConnected) return

        Object.entries(this.configValue).forEach(([key, value]) => {
            window[`rakuten_${key}`] = value
        })

        const originalWrite = document.write
        document.write = (...html) => {
            this.slotTarget.insertAdjacentHTML("beforeend", html.join(""))
            this.element.dataset.filled = ""
        }

        return new Promise((resolve) => {
            const script = document.createElement("script")
            script.src = WIDGET_SRC
            script.onload = script.onerror = () => {
                document.write = originalWrite
                script.remove()
                resolve()
            }
            document.head.appendChild(script)
        })
    }
}
