import { Controller } from "@hotwired/stimulus"

// 商品名とアーティストタグを合わせた表示領域が、カードの高さに収まりきらない場合のみ
// 下端をフェードアウトさせる。商品名の長さによってグラデーションの位置がばらつかないよう、
// 商品名単独・アーティスト単独ではなく両者をまとめたコンテナの溢れをレイアウト後に
// scrollHeightで検知してからマスクを適用する。
// フェードアウトが発生する場合のみ、発売日との余白も詰める（フェードなしの場合は詰めない）。
const FADE_MASK_CLASSES = [
    "[mask-image:linear-gradient(to_bottom,black_63%,transparent_100%)]",
    "[-webkit-mask-image:linear-gradient(to_bottom,black_63%,transparent_100%)]",
]

export default class extends Controller {
    static targets = ["content", "date"]

    connect() {
        if (this.contentTarget.scrollHeight > this.contentTarget.clientHeight) {
            this.contentTarget.classList.add(...FADE_MASK_CLASSES)
            this.dateTarget.classList.replace("pt-2", "pt-1")
        }
    }
}
