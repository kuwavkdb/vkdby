import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = ["placeholder", "graphArea", "container", "fullscreenBtn", "nodeCount"]

  connect() {
    this.fullscreenBtnTarget.addEventListener("pointerdown", (e) => {
      e.preventDefault()
      this.toggleFullscreen(e)
    })
    if (window.location.hash === "#relationship-graph") {
      this.load()
    }
  }

  async load() {
    if (this._loaded) return
    this._loaded = true

    this.placeholderTarget.innerHTML =
      '<span class="text-sm text-slate-400 dark:text-slate-500">読み込み中...</span>'

    const cytoscape = window.cytoscape
    if (!cytoscape) {
      console.error("unit-graph: cytoscape not loaded")
      return
    }

    let data
    try {
      const res = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      data = await res.json()
    } catch (e) {
      console.error("unit-graph: fetch failed", e)
      return
    }

    const { nodes, edges } = data
    if (!nodes || nodes.length <= 1) {
      this.placeholderTarget.innerHTML =
        '<span class="text-sm text-slate-400 dark:text-slate-500">関連ユニットが見つかりませんでした</span>'
      return
    }

    this.placeholderTarget.classList.add("hidden")
    this.graphAreaTarget.classList.remove("hidden")
    this.fullscreenBtnTarget.classList.remove("hidden")
    this.nodeCountTarget.textContent = `${nodes.length} nodes`
    this.nodeCountTarget.classList.remove("hidden")

    const isDark = document.documentElement.classList.contains("dark")
    const containerW = this.containerTarget.offsetWidth || 800
    const containerH = this.containerTarget.offsetHeight || 420

    this.cy = cytoscape({
      container: this.containerTarget,
      elements: [...nodes, ...edges],
      style: [
        {
          selector: 'node[hop = 1]',
          style: { "z-index": 300 },
        },
        {
          selector: 'node[hop = 2]',
          style: { "z-index": 200 },
        },
        {
          selector: 'node[type="unit"]',
          style: {
            "background-color": "#94a3b8",
            "background-opacity": 0.7,
            "label": "data(label)",
            "color": "#ffffff",
            "text-valign": "center",
            "text-halign": "center",
            "font-size": "10px",
            "font-weight": "bold",
            "width": "label",
            "height": "label",
            "shape": "round-rectangle",
            "padding": "8px 16px",
            "text-wrap": "wrap",
            "text-max-width": "120px",
            "cursor": "pointer",
            "border-width": 2,
            "border-color": "#64748b",
          },
        },
        {
          selector: 'node[type="unit"].snapshot-current',
          style: {
            "background-color": "#6366f1",
            "background-opacity": 0.75,
            "border-color": "#4338ca",
          },
        },
        {
          selector: 'node[type="unit"].center',
          style: {
            "background-color": "#dc2626",
            "background-opacity": 1,
            "border-width": 3,
            "border-color": "#fca5a5",
            "z-index": 9999,
          },
        },
        {
          selector: "node.newly-added",
          style: {
            "background-color": "#0d9488",
            "background-opacity": 0.85,
            "border-color": "#0f766e",
          },
        },
        {
          selector: "edge[current = 1]",
          style: {
            "width": 2,
            "line-color": isDark ? "#94a3b8" : "#64748b",
            "curve-style": "bezier",
            "opacity": 0.8,
            "target-arrow-shape": "triangle",
            "target-arrow-color": isDark ? "#94a3b8" : "#64748b",
            "arrow-scale": 0.8,
          },
        },
        {
          selector: "edge[current = 0]",
          style: {
            "width": 1.5,
            "line-color": isDark ? "#475569" : "#94a3b8",
            "line-style": "dashed",
            "line-dash-pattern": [4, 3],
            "curve-style": "bezier",
            "opacity": 0.6,
            "target-arrow-shape": "triangle",
            "target-arrow-color": isDark ? "#475569" : "#94a3b8",
            "arrow-scale": 0.7,
          },
        },
        {
          selector: "edge.dragging",
          style: {
            "width": 3,
            "opacity": 1,
          },
        },
        {
          selector: "node.neighbor-highlight",
          style: {
            "border-width": 3,
            "border-color": "#f59e0b",
            "background-opacity": 1,
          },
        },
        {
          selector: "node:selected",
          style: {
            "border-width": 3,
            "border-color": "#f59e0b",
          },
        },
        {
          selector: "node:active",
          style: {
            "overlay-opacity": 0.2,
          },
        },
      ],
      layout: {
        name: "cose",
        padding: 40,
        boundingBox: { x1: 0, y1: 0, w: containerW, h: containerH },
        nodeRepulsion: 600000,
        idealEdgeLength: 250,
        nodeOverlap: 80,
        gravity: 0.1,
        numIter: 2000,
        animate: false,
        fit: true,
      },
    })

    // 中心ノードを確実に最前面に（スタイルシートより優先）
    this.cy.nodes(".center").style("z-index", 9999)

    this.cy.on("tap", "node", (evt) => {
      const url = evt.target.data("url")
      if (url) window.location.href = url
    })

    this.cy.on("grabon", "node", (evt) => {
      const node = evt.target
      node.connectedEdges().addClass("dragging")
      node.neighborhood("node").addClass("neighbor-highlight")
    })

    this.cy.on("free", "node", (evt) => {
      const node = evt.target
      node.connectedEdges().removeClass("dragging")
      node.neighborhood("node").removeClass("neighbor-highlight")
    })

    this.cy.on("mouseover", "node", () => {
      this.containerTarget.style.cursor = "pointer"
    })

    this.cy.on("mouseout", "node", () => {
      this.containerTarget.style.cursor = "default"
    })
  }

  async _expandNode(node, graphUrl) {
    if (node.data("expanding")) return
    node.data("expanding", true)

    let data
    try {
      const res = await fetch(graphUrl, { headers: { Accept: "application/json" } })
      data = await res.json()
    } catch (e) {
      console.error("unit-graph: expand fetch failed", e)
      node.data("expanding", false)
      return
    }

    const existingIds = new Set(this.cy.elements().map((el) => el.id()))
    const newNodes = (data.nodes || []).filter((n) => !existingIds.has(n.data.id))
    const newEdges = (data.edges || []).filter((e) => !existingIds.has(e.data.id))

    if (newNodes.length === 0 && newEdges.length === 0) {
      node.data("expanding", false)
      return
    }

    this.cy.nodes(".newly-added").removeClass("newly-added")

    const existingNodes = this.cy.nodes()
    existingNodes.lock()

    const origin = node.position()
    const spread = 80
    const positionedNodes = newNodes.map((n) => ({
      ...n,
      position: {
        x: origin.x + (Math.random() - 0.5) * spread,
        y: origin.y + (Math.random() - 0.5) * spread,
      },
    }))
    const added = this.cy.add([...positionedNodes, ...newEdges])
    added.nodes().addClass("newly-added")

    const container = this.containerTarget
    const w = container.offsetWidth || 800
    const h = container.offsetHeight || 420

    this.cy.layout({
      name: "cose",
      padding: 40,
      boundingBox: { x1: 0, y1: 0, w, h },
      nodeRepulsion: 600000,
      idealEdgeLength: 250,
      nodeOverlap: 80,
      gravity: 0.1,
      numIter: 2000,
      animate: false,
      fit: false,
    }).run()

    existingNodes.unlock()
    node.data("expanding", false)
  }

  disconnect() {
    this._collapse()
  }

  toggleFullscreen(e) {
    e?.preventDefault()
    if (this._lastCollapseAt && Date.now() - this._lastCollapseAt < 400) return
    if (this.containerTarget.classList.contains("unit-graph--expanded")) {
      this._collapse()
    } else {
      this._expand()
    }
  }

  _expand() {
    const container = this.containerTarget
    container.classList.add("unit-graph--expanded")
    // 上部 48px をヘッダーバー用に空ける（Cytoscape キャンバスと重ならない領域）
    container.style.cssText = "position:fixed;top:48px;left:0;right:0;bottom:0;z-index:9999;border-radius:0;border:none;"

    const isDark = document.documentElement.classList.contains("dark")
    const textColor = isDark ? "#94a3b8" : "#64748b"
    const mutedColor = isDark ? "#64748b" : "#94a3b8"

    // キャンバスと重ならない上部ヘッダーバーに凡例と閉じるボタンを配置
    const header = document.createElement("div")
    const bgColor = isDark ? "#000000" : "#ffffff"
    header.style.cssText = `position:fixed;top:0;left:0;right:0;height:48px;z-index:10000;background:${bgColor};display:flex;align-items:center;justify-content:space-between;padding:0 1rem;`

    // 凡例（PC のみ表示）
    const isPC = window.matchMedia("(min-width: 768px)").matches
    if (isPC) {
      const legend = document.createElement("div")
      legend.style.cssText = `display:flex;align-items:center;gap:0.75rem;font-size:0.75rem;color:${textColor};`
      legend.innerHTML = `
        <span style="display:flex;align-items:center;gap:0.375rem;">
          <span style="display:inline-block;width:0.75rem;height:0.75rem;border-radius:2px;background:#dc2626;" aria-hidden="true"></span>
          このユニット
        </span>
        <span style="display:flex;align-items:center;gap:0.375rem;">
          <span style="display:inline-block;width:0.75rem;height:0.75rem;border-radius:2px;background:#6366f1;" aria-hidden="true"></span>
          直接の関連ユニット
        </span>
        <span style="display:flex;align-items:center;gap:0.375rem;">
          <svg width="24" height="8" aria-hidden="true"><line x1="0" y1="4" x2="24" y2="4" stroke="${textColor}" stroke-width="2"/></svg>
          現在の関連
        </span>
        <span style="display:flex;align-items:center;gap:0.375rem;color:${mutedColor};">
          <svg width="24" height="8" aria-hidden="true"><line x1="0" y1="4" x2="24" y2="4" stroke="${mutedColor}" stroke-width="1.5" stroke-dasharray="4 3"/></svg>
          過去の関連
        </span>
      `
      header.appendChild(legend)
    }

    const btn = document.createElement("button")
    btn.setAttribute("aria-label", "縮小")
    btn.style.cssText = `background:none;color:${textColor};border:none;font-size:1.5rem;cursor:pointer;padding:0.5rem;touch-action:manipulation;user-select:none;line-height:1;margin-left:auto;`
    btn.textContent = "✕"
    btn.addEventListener("pointerdown", (e) => { e.preventDefault(); this._collapse() })
    header.appendChild(btn)
    document.body.appendChild(header)
    this._bodyCloseBtn = header

    document.body.style.overflow = "hidden"
    this.cy?.resize()
    this.cy?.fit(undefined, 40)
  }

  _collapse() {
    if (!this.hasContainerTarget) return
    this._lastCollapseAt = Date.now()
    const container = this.containerTarget
    container.classList.remove("unit-graph--expanded")
    container.style.cssText = "height:420px;position:relative;"

    this._bodyCloseBtn?.remove()
    this._bodyCloseBtn = null

    document.body.style.overflow = ""
    this.cy?.resize()
    this.cy?.fit(undefined, 40)
  }
}
