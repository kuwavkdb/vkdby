import { Controller } from "@hotwired/stimulus"

// ドラッグで並び替えた結果は自動保存せず、saveButton を押したときにまとめて PATCH する。
// list ターゲットが並び替え対象の要素、saveButton / status は見出し行に置く。

// 並び順が未保存のコントローラー。離脱ガードはページ全体で1つだけ登録し、確認は1回にまとめる
const dirtyControllers = new Set()
let guardInstalled = false
let submitting = false

function installGuard() {
    if (guardInstalled) return
    guardInstalled = true

    // フォーム送信（リンクの保存・削除など）に伴う遷移では確認しない
    document.addEventListener("submit", () => { submitting = true })
    document.addEventListener("turbo:submit-end", () => { submitting = false })
    document.addEventListener("turbo:load", () => { submitting = false })

    window.addEventListener("beforeunload", (event) => {
        if (submitting || dirtyControllers.size === 0) return
        event.preventDefault()
        event.returnValue = ""
    })
    document.addEventListener("turbo:before-visit", (event) => {
        if (submitting || dirtyControllers.size === 0) return
        if (!confirm("並び順が保存されていません。このページを離れますか？")) event.preventDefault()
    })
    // 未保存の並びをキャッシュに残さない（「戻る」で復元されたときに保存済み扱いになるのを防ぐ）
    document.addEventListener("turbo:before-cache", () => {
        dirtyControllers.forEach(controller => controller.restoreSavedOrder())
    })
}

export default class extends Controller {
    static values = { url: String }
    static targets = ["list", "saveButton", "status"]

    async connect() {
        installGuard()
        this.savedIds = this.currentIds()
        this.updateButton()

        const { default: Sortable } = await import("sortablejs")
        // import の待機中に切り離された場合や、再接続で作成済みの場合は何もしない
        if (!this.element.isConnected || this.sortable) return

        this.sortable = Sortable.create(this.listTarget, {
            handle: ".drag-handle",
            onEnd: this.onEnd.bind(this)
        })
    }

    disconnect() {
        dirtyControllers.delete(this)
        if (this.sortable) this.sortable.destroy()
        this.sortable = null
    }

    onEnd() {
        this.showStatus("")
        this.updateButton()
    }

    async save() {
        if (!this.isDirty()) return

        const ids = this.currentIds()
        const csrfToken = document.querySelector("[name='csrf-token']").content

        this.saveButtonTarget.disabled = true
        this.showStatus("保存中…")

        try {
            const response = await fetch(this.urlValue, {
                method: "PATCH",
                headers: {
                    "Content-Type": "application/json",
                    "X-CSRF-Token": csrfToken
                },
                body: JSON.stringify({ ids: ids })
            })
            if (!response.ok) throw new Error(response.status)

            this.savedIds = ids
            this.showStatus("並び順を保存しました")
        } catch (error) {
            this.showStatus("保存に失敗しました")
            alert("並び順の保存に失敗しました。もう一度お試しください。")
        } finally {
            this.updateButton()
        }
    }

    restoreSavedOrder() {
        const items = new Map(Array.from(this.listTarget.children).map(child => [child.dataset.id, child]))
        if (!this.savedIds.every(id => items.has(id))) return

        this.savedIds.forEach(id => this.listTarget.appendChild(items.get(id)))
        this.updateButton()
    }

    currentIds() {
        return Array.from(this.listTarget.children).map(child => child.dataset.id)
    }

    isDirty() {
        return this.currentIds().join(",") !== this.savedIds.join(",")
    }

    updateButton() {
        const dirty = this.isDirty()
        if (dirty) dirtyControllers.add(this)
        else dirtyControllers.delete(this)

        if (this.hasSaveButtonTarget) this.saveButtonTarget.disabled = !dirty
    }

    showStatus(message) {
        if (this.hasStatusTarget) this.statusTarget.textContent = message
    }
}
