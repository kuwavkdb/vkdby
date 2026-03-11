import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { data: Object }

  connect() {
    const { nodes, edges } = this.dataValue
    if (!nodes || nodes.length === 0) return

    const cytoscape = window.cytoscape
    if (!cytoscape) {
      console.error("unit-graph: cytoscape not loaded")
      return
    }

    const isDark = document.documentElement.classList.contains("dark")

    const cy = cytoscape({
      container: this.element,
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
          selector: 'node[type="person"]',
          style: {
            "background-color": "#10b981",
            "label": "data(label)",
            "color": "#ffffff",
            "text-valign": "center",
            "text-halign": "center",
            "font-size": "9px",
            "font-weight": "bold",
            "width": 56,
            "height": 56,
            "shape": "ellipse",
            "text-wrap": "wrap",
            "text-max-width": "52px",
            "cursor": "pointer",
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

    cy.on("tap", "node", (evt) => {
      const url = evt.target.data("url")
      if (url) window.location.href = url
    })

    cy.on("mouseover", "node", () => {
      this.element.style.cursor = "pointer"
    })

    cy.on("mouseout", "node", () => {
      this.element.style.cursor = "default"
    })
  }
}
