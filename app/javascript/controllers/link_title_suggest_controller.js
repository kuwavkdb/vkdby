import { Controller } from "@hotwired/stimulus"

// リンク欄全体に1つだけ付け、各行（data-link-title-suggest-row）の URL 欄から、同じ行のタイトル欄（data-link-title-suggest-title）を補完する
export default class extends Controller {
    // 管理画面の外部サイトに登録された表示名と URL パターン（[{ name, url_pattern }]）
    static values = { sites: Array }

    suggest(event) {
        const urlInput = event.target
        const titleInput = urlInput
            .closest("[data-link-title-suggest-row]")
            ?.querySelector("[data-link-title-suggest-title]")
        if (!titleInput) return

        const normalized = this.normalizeXAccount(urlInput.value.trim())
        if (normalized) {
            urlInput.value = normalized
        }

        if (titleInput.value.trim() !== "") return

        const guessed = this.guessTitle(urlInput.value.trim())
        if (guessed) {
            titleInput.value = guessed
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

        const registered = this.guessTitleFromSites(url)
        if (registered) return registered

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

    // 外部サイトの url_pattern（例: https://ameblo.jp/{account}/）の {account} を任意の文字列とみなして照合する。
    // スキームと先頭の www. は区別せず、パターンより後ろに続くパス・クエリがあっても一致とする
    guessTitleFromSites(url) {
        const target = this.stripScheme(url.href)
        const site = this.sitesValue.find((s) => s.name && this.sitePatternRegExp(s.url_pattern)?.test(target))
        return site ? site.name : null
    }

    sitePatternRegExp(pattern) {
        if (!pattern || !pattern.includes("{account}")) return null

        const body = this.stripScheme(pattern).replace(/\/+$/, "")
        const source = body
            .split("{account}")
            .map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
            .join("[^/?#&]+")
        return new RegExp(`^${source}(?:[/?#&].*)?$`, "i")
    }

    stripScheme(value) {
        return value.trim().replace(/^https?:\/\//i, "").replace(/^www\./i, "")
    }
}
