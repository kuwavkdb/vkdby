import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["title", "url"]

    suggest() {
        const normalized = this.normalizeXAccount(this.urlTarget.value.trim())
        if (normalized) {
            this.urlTarget.value = normalized
        }

        if (this.titleTarget.value.trim() !== "") return

        const guessed = this.guessTitle(this.urlTarget.value.trim())
        if (guessed) {
            this.titleTarget.value = guessed
        }
    }

    // "@xxxxx" 形式で入力された場合はXアカウントとみなし、通常のURLに変換する
    normalizeXAccount(rawUrl) {
        const matched = rawUrl.match(/^@(\w{1,15})$/)
        if (!matched) return null

        return `https://x.com/${matched[1]}`
    }

    guessTitle(rawUrl) {
        if (!rawUrl) return null

        let url
        try {
            url = new URL(/^https?:\/\//i.test(rawUrl) ? rawUrl : `https://${rawUrl}`)
        } catch {
            return null
        }

        const host = url.hostname.replace(/^www\./i, "").toLowerCase()
        const path = url.pathname

        if (host === "x.com" || host === "twitter.com") {
            if (/^\/[^/]+\/status\/\d+/.test(path)) return "X Post"
            return "X"
        }
        if (host === "open.spotify.com") return "Spotify"
        if (host === "youtube.com" || host === "m.youtube.com") {
            if (/^\/(?:watch|shorts\/)/.test(path)) return "YouTube Movie"
            if (/^\/(?:@|channel\/|c\/|user\/)/.test(path)) return "YouTube Channel"
            return "YouTube"
        }
        if (host === "youtu.be") return "YouTube Movie"
        if (host === "instagram.com") return "Instagram"
        if (host === "tiktok.com") return "TikTok"
        if (host === "facebook.com" || host === "fb.com") return "Facebook"
        if (host === "nicovideo.jp") return "niconico"

        return null
    }
}
