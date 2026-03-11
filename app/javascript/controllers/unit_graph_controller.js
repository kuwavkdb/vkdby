import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = ["placeholder", "graphArea", "container", "closeBtn", "fullscreenBtn", "nodeCount"]

  connect() {
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
          selector: 'node[type="unit"]',
          style: {
            "background-color": "#6366f1",
            "background-opacity": 0.75,
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
            "border-color": "#4338ca",
          },
        },
        {
          selector: 'node[type="unit"][?current]',
          style: {
            "background-color": "#dc2626",
            "background-opacity": 1,
            "border-width": 3,
            "border-color": "#fca5a5",
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
          selector: "edge",
          style: {
            "width": 1.5,
            "line-color": isDark ? "#475569" : "#cbd5e1",
            "curve-style": "bezier",
            "opacity": 0.7,
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

    this.cy.on("tap", "node", (evt) => {
      const graphUrl = evt.target.data("graph_url")
      if (graphUrl) this._expandNode(evt.target, graphUrl)
    })

    this.cy.on("dblclick", "node", (evt) => {
      const url = evt.target.data("url")
      if (url) window.location.href = url
    })

    this.cy.on("grabon", "node", (evt) => {
      evt.target.connectedEdges().addClass("dragging")
    })

    this.cy.on("free", "node", (evt) => {
      evt.target.connectedEdges().removeClass("dragging")
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

  toggleFullscreen() {
    if (this.containerTarget.classList.contains("unit-graph--expanded")) {
      this._collapse()
    } else {
      this._expand()
    }
  }

  _expand() {
    const container = this.containerTarget
    container.classList.add("unit-graph--expanded")
    container.style.cssText = [
      "position:fixed",
      "inset:0",
      "z-index:9999",
      "width:100vw",
      "height:100vh",
      "border-radius:0",
      "border:none",
    ].join(";")
    this.closeBtnTarget.style.display = "block"
    document.body.style.overflow = "hidden"
    this.cy?.resize()
    this.cy?.fit(undefined, 40)
  }

  _collapse() {
    if (!this.hasContainerTarget) return
    const container = this.containerTarget
    container.classList.remove("unit-graph--expanded")
    container.style.cssText = "height:420px;position:relative;"
    if (this.hasCloseBtnTarget) this.closeBtnTarget.style.display = "none"
    document.body.style.overflow = ""
    this.cy?.resize()
    this.cy?.fit(undefined, 40)
  }
}
