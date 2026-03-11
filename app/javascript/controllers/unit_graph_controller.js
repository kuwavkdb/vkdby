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
        name: "cose",
        padding: 20,
        nodeRepulsion: 8000,
        idealEdgeLength: 80,
        animate: false,
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

    this._onFullscreenChange = () => this.cy.resize()
    document.addEventListener("fullscreenchange", this._onFullscreenChange)
  }

  disconnect() {
    document.removeEventListener("fullscreenchange", this._onFullscreenChange)
  }

  toggleFullscreen() {
    const container = this.containerTarget
    if (!document.fullscreenElement) {
      container.requestFullscreen().then(() => {
        container.style.height = "100vh"
        container.style.borderRadius = "0"
        this.cy?.resize()
      })
    } else {
      document.exitFullscreen().then(() => {
        container.style.height = "420px"
        container.style.borderRadius = ""
        this.cy?.resize()
      })
    }
  }
}
