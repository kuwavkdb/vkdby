// 地図アダプターが外部（CDN）のスクリプト・スタイルシートを必要になったときに1回だけ読み込む（issue #1801）。
// 地図を表示するページでだけ読み込み、ほかのページを重くしないため。integrity（SRI）で改ざんを検知する
const loaded = new Map()

function load(key, createElement) {
  if (!loaded.has(key)) {
    loaded.set(key, new Promise((resolve, reject) => {
      const element = createElement()
      element.addEventListener("load", () => resolve(), { once: true })
      element.addEventListener("error", () => {
        loaded.delete(key)
        element.remove()
        reject(new Error(`Failed to load ${key}`))
      }, { once: true })
      document.head.appendChild(element)
    }))
  }
  return loaded.get(key)
}

export function loadStylesheet({ href, integrity }) {
  return load(href, () => {
    const link = document.createElement("link")
    link.rel = "stylesheet"
    link.href = href
    if (integrity) {
      link.integrity = integrity
      link.crossOrigin = "anonymous"
    }
    return link
  })
}

export function loadScript({ src, integrity }) {
  return load(src, () => {
    const script = document.createElement("script")
    script.src = src
    script.async = false
    if (integrity) {
      script.integrity = integrity
      script.crossOrigin = "anonymous"
    }
    return script
  })
}
