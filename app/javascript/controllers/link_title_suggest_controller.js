import { Controller } from "@hotwired/stimulus"

// リンク欄全体に1つだけ付け、各行（data-link-title-suggest-row）の URL 欄から、同じ行のタイトル欄（data-link-title-suggest-title）を補完する
export default class extends Controller {
    // sites: 管理画面の外部サイトに登録された表示名と URL パターン（[{ name, url_pattern }]）
    // builtins: 登録しなくても補完できるサービスの対応表（ExternalSite::BUILTIN_LINK_TITLES）
    static values = { sites: Array, builtins: Array }

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

        return this.guessTitleFromBuiltins(host, path)
    }

    guessTitleFromBuiltins(host, path) {
        for (const service of this.builtinsValue) {
            const rule = service.rules.find(
                (r) => r.hosts.includes(host) && (!r.path || new RegExp(r.path).test(path))
            )
            if (rule) return rule.title
        }
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
