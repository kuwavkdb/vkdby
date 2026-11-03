import { Controller } from "@hotwired/stimulus"

// ユニットページのスナップショットで、メンバーを入力のたびに絞り込む（issue #1999）。
// toggleコントローラと同じ要素（section）に付け、開いている間だけ入力欄を出す。
// 行に表示されている文字（パート・名前・経歴など）すべてを対象にし、一致した箇所を<mark>で強調する。
// 管理者向けの編集リンク（data-member-filter-ignore）と画面読み上げ用の文字（.sr-only）は対象にしない
export default class extends Controller {
    static targets = ["row", "form", "input", "status"]
    static values = { markClass: String }

    connect() {
        if (this.element.dataset.toggleOpenValue === "true") this.show()
    }

    show() {
        this.formTarget.hidden = false
        this.apply()
    }

    // 閉じたら入力欄を隠し、絞り込みも解除する
    hide() {
        this.formTarget.hidden = true
        this.inputTarget.value = ""
        this.apply()
    }

    filter() {
        this.apply()
    }

    // 過去のスナップショットは開いたあとにメンバー行を読み込むため、読み込まれた行にも絞り込みを当てる。
    // 行ごとに呼ばれるので、まとめて1回だけ当てる
    rowTargetConnected() {
        if (this.scheduled) return

        this.scheduled = true
        requestAnimationFrame(() => {
            this.scheduled = false
            this.apply()
        })
    }

    apply() {
        const terms = normalize(this.inputTarget.value).split(/\s+/).filter(Boolean)
        let matched = 0

        this.rowTargets.forEach(row => {
            this.clearMarks(row)
            if (terms.length === 0) {
                row.hidden = false
                return
            }

            const nodes = this.textNodes(row).map(node => ({ node, ...normalizeWithMap(node.data) }))
            const text = nodes.map(n => n.text).join("\n")
            const hit = terms.every(term => text.includes(term))
            row.hidden = !hit
            if (hit) {
                matched++
                nodes.forEach(n => this.highlight(n, terms))
            }
        })

        this.updateStatus(terms.length > 0, matched)
    }

    updateStatus(filtering, matched) {
        const total = this.rowTargets.length
        if (!filtering || total === 0) {
            this.statusTarget.textContent = ""
        } else if (matched === 0) {
            this.statusTarget.textContent = "該当するメンバーはいません"
        } else {
            this.statusTarget.textContent = `${total}人中${matched}人`
        }
    }

    textNodes(row) {
        const walker = document.createTreeWalker(row, NodeFilter.SHOW_TEXT, {
            acceptNode: node => {
                if (!node.data.trim()) return NodeFilter.FILTER_REJECT
                if (node.parentElement.closest("[data-member-filter-ignore], .sr-only")) return NodeFilter.FILTER_REJECT
                return NodeFilter.FILTER_ACCEPT
            }
        })
        const nodes = []
        while (walker.nextNode()) nodes.push(walker.currentNode)
        return nodes
    }

    // 1つの文字ノードの中で一致した範囲を<mark>で囲む。後ろから囲むと前の範囲の位置がずれない
    highlight({ node, text, starts, ends }, terms) {
        const ranges = []
        terms.forEach(term => {
            let index = text.indexOf(term)
            while (index !== -1) {
                ranges.push([starts[index], ends[index + term.length - 1]])
                index = text.indexOf(term, index + term.length)
            }
        })
        mergeRanges(ranges).reverse().forEach(([start, end]) => {
            const target = node.splitText(start)
            target.splitText(end - start)
            const mark = document.createElement("mark")
            mark.dataset.memberFilterMark = ""
            mark.className = this.markClassValue
            target.replaceWith(mark)
            mark.appendChild(target)
        })
    }

    clearMarks(row) {
        row.querySelectorAll("mark[data-member-filter-mark]").forEach(mark => {
            const parent = mark.parentNode
            mark.replaceWith(...mark.childNodes)
            parent.normalize()
        })
    }
}

// 大文字と小文字、全角と半角を同じとみなす（ひらがなとカタカナは区別する）
function normalize(string) {
    return Array.from(string, char => char.normalize("NFKC").toLowerCase()).join("")
}

// 正規化した文字列と、その各位置が元の文字列のどの文字の始まりと終わりにあたるかを返す。
// 1文字が複数文字に展開されることがある（例: ㈱）ため、位置の対応を持っておく
function normalizeWithMap(string) {
    let text = ""
    const starts = []
    const ends = []
    let offset = 0
    for (const char of string) {
        const normalized = char.normalize("NFKC").toLowerCase()
        for (let i = 0; i < normalized.length; i++) {
            starts.push(offset)
            ends.push(offset + char.length)
        }
        text += normalized
        offset += char.length
    }
    return { text, starts, ends }
}

function mergeRanges(ranges) {
    const sorted = ranges.sort((a, b) => a[0] - b[0])
    const merged = []
    sorted.forEach(range => {
        const last = merged[merged.length - 1]
        if (last && range[0] <= last[1]) {
            last[1] = Math.max(last[1], range[1])
        } else {
            merged.push([...range])
        }
    })
    return merged
}
