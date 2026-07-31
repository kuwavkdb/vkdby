import { Controller } from "@hotwired/stimulus"

// 参加アーティストのタグが3行を超えて折り返された場合のみ、下端をフェードアウトさせる。
// アーティスト数ではなく実際の折り返し行数（バンド名の長さで変わる）で判定するため、
// レイアウト後にscrollHeightで溢れを検知してからマスクを適用する。
const FADE_MASK_CLASSES = [
    "[mask-image:linear-gradient(to_bottom,black_63%,transparent_100%)]",
    "[-webkit-mask-image:linear-gradient(to_bottom,black_63%,transparent_100%)]",
]

export default class extends Controller {
    connect() {
        if (this.element.scrollHeight > this.element.clientHeight) {
            this.element.classList.add(...FADE_MASK_CLASSES)
        }
    }
}
