import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { data: Object }
  static targets = ["container"]

  connect() {
    const { nodes, edges } = this.dataValue
    if (!nodes || nodes.length === 0) return

    const cytoscape = window.cytoscape
    if (!cytoscape) {
      console.error("unit-graph: cytoscape not loaded")
      return
    }

    const isDark = document.documentElement.classList.contains("dark")

    const rootId = nodes.find(n => n.data.current)?.data.id

    this.cy = cytoscape({
      container: this.containerTarget,
      elements: [...nodes, ...edges],
      style: [
        {
          selector: 'node[type="unit"]',
          style: {
            "background-color": "#6366f1",
            "label": "data(label)",
            "color": "#ffffff",
            "text-valign": "center",
            "text-halign": "center",
            "font-size": "10px",
            "font-weight": "bold",
            "width": "label",
            "height": 32,
            "shape": "round-rectangle",
            "padding": "8px",
            "text-wrap": "wrap",
            "text-max-width": "120px",
            "cursor": "pointer",
          },
        },
        {
          selector: 'node[type="unit"][?current]',
          style: {
            "background-color": "#dc2626",
            "border-width": 3,
            "border-color": "#fca5a5",
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
        name: "breadthfirst",
        padding: 40,
        spacingFactor: 1.8,
        directed: false,
        roots: rootId ? [`#${rootId}`] : undefined,
        animate: false,
        fit: true,
      },
    })

    this.cy.on("tap", "node", (evt) => {
      const url = evt.target.data("url")
      if (url) window.location.href = url
    })

    this.cy.on("mouseover", "node", () => {
      this.containerTarget.style.cursor = "pointer"
    })

    this.cy.on("mouseout", "node", () => {
      this.containerTarget.style.cursor = "default"
    })

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
    document.body.style.overflow = "hidden"
    this.cy?.resize()
  }

  _collapse() {
    const container = this.containerTarget
    container.classList.remove("unit-graph--expanded")
    container.style.cssText = "height:420px;"
    document.body.style.overflow = ""
    this.cy?.resize()
  }
}
