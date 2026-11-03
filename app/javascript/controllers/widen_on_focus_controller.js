import { Controller } from "@hotwired/stimulus"

// フォーカスがある間だけ、要素の横幅を枠（data-widen-on-focus-boundary を付けた祖先）いっぱいまで広げる（issue #2004）。
// 旧Wikiテキスト欄のように、狭いカラムに置かれた長い行のテキストを確認しやすくするためのもの。
// 他の項目の上に重ねて表示し、高さ（利用者がつまんで変えたものを含む）には触らない。
// 枠と要素の幅がほぼ同じ（1カラム表示の狭い画面など）ときは何もしない
export default class extends Controller {
    widen() {
        const boundary = this.element.closest("[data-widen-on-focus-boundary]")
        if (!boundary) return

        const boundaryRect = boundary.getBoundingClientRect()
        const rect = this.element.getBoundingClientRect()
        if (boundaryRect.width - rect.width < 1) return

        this.element.style.position = "relative"
        this.element.style.zIndex = "20"
        this.element.style.left = `${boundaryRect.left - rect.left}px`
        this.element.style.width = `${boundaryRect.width}px`
    }

    restore() {
        this.element.style.position = ""
        this.element.style.zIndex = ""
        this.element.style.left = ""
        this.element.style.width = ""
    }
}
