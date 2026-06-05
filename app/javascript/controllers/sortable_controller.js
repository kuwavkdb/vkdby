import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { url: String }

    async connect() {
        const { default: Sortable } = await import("sortablejs")
        this.sortable = Sortable.create(this.element, {
            handle: ".drag-handle",
            onEnd: this.onEnd.bind(this)
        })
    }

    onEnd(event) {
        const ids = Array.from(this.element.children).map(child => child.dataset.id)

        const url = this.urlValue
        const csrfToken = document.querySelector("[name='csrf-token']").content

        fetch(url, {
            method: "PATCH",
            headers: {
                "Content-Type": "application/json",
                "X-CSRF-Token": csrfToken
            },
            body: JSON.stringify({ ids: ids })
        })
    }
}
