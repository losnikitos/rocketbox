import { Controller } from "@hotwired/stimulus"
import dagre from "@dagrejs/dagre"

// Lays out the node targets left to right and draws the edges ([from id, to id]) as curved arrows.
// Nodes with data-x/data-y (their centre) stay there instead. Nodes can be dragged around (flow:moved with the new
// centre) and the canvas pinch-zoomed; zoom and scroll survive reloads of the page.
// Dragging from a node's [data-flow-handle] onto another node dispatches flow:linked with both ids.
export default class extends Controller {
  static targets = ["canvas", "node", "edges"]
  static values = { edges: Array }

  connect() {
    this.scale = 1
    const g = this.graph = new dagre.graphlib.Graph()
    g.setGraph({ rankdir: "LR", nodesep: 24, ranksep: 72, marginx: 4, marginy: 4 })
    g.setDefaultEdgeLabel(() => ({}))
    // Edges attach at the middle of the node's first child (a folder's icon, a recipe's whole box), not the label below.
    this.nodeTargets.forEach(el => {
      const anchor = el.firstElementChild.offsetHeight / 2, handle = el.querySelector("[data-flow-handle]")
      if (handle) handle.style.top = `${anchor}px`
      g.setNode(el.dataset.id, { el, width: el.offsetWidth, height: el.offsetHeight, anchor })
    })
    this.edgesValue.forEach(([from, to]) => g.setEdge(from, to))
    dagre.layout(g)

    g.nodes().forEach(id => {
      const node = g.node(id), { x, y } = node.el.dataset
      if (x) Object.assign(node, { x: +x, y: +y, moved: true })
      place(node)
    })
    const view = JSON.parse(sessionStorage.getItem(this.key) || "null")
    if (view) this.canvasTarget.style.zoom = this.scale = view.scale
    this.resize()
    this.draw()
    if (view) Object.assign(this.element, { scrollLeft: view.left, scrollTop: view.top })
    this.canvasTarget.classList.remove("invisible")
  }

  // Trackpad pinch arrives as a wheel event with ctrlKey (Chrome, Firefox); plain scrolling pans.
  wheel(event) {
    if (!event.ctrlKey) return
    event.preventDefault()
    this.zoom(this.scale * Math.exp(-event.deltaY / 100), event)
  }

  // Safari sends pinch as gesture events with a scale relative to the gesture's start.
  gesture(event) {
    event.preventDefault()
    if (event.type === "gesturestart") this.gestureScale = this.scale
    else this.zoom(this.gestureScale * event.scale, event)
  }

  // Zooms to `scale`, keeping the canvas point under the pointer in place.
  zoom(scale, { clientX, clientY }) {
    const box = this.element.getBoundingClientRect(), mx = clientX - box.left, my = clientY - box.top
    const x = (this.element.scrollLeft + mx) / this.scale, y = (this.element.scrollTop + my) / this.scale
    this.scale = Math.min(2, Math.max(0.2, scale))
    this.canvasTarget.style.zoom = this.scale
    this.resize()
    this.element.scrollLeft = x * this.scale - mx
    this.element.scrollTop = y * this.scale - my
    this.remember()
  }

  remember() {
    sessionStorage.setItem(this.key, JSON.stringify({ scale: this.scale, left: this.element.scrollLeft, top: this.element.scrollTop }))
  }

  get key() { return `flow:${location.pathname}` }

  grab(event) {
    if (event.button !== 0) return
    const id = event.currentTarget.dataset.id
    this.dragged = false
    this.dragging = { id, node: this.graph.node(id), x: event.clientX, y: event.clientY, moved: false }
    event.currentTarget.setPointerCapture(event.pointerId)
    event.currentTarget.style.zIndex = this.z = (this.z || 0) + 1
  }

  drag(event) {
    const d = this.dragging
    if (!d) return
    const dx = event.clientX - d.x, dy = event.clientY - d.y
    if (!d.moved && Math.hypot(dx, dy) < 4) return
    d.moved = d.node.moved = true
    d.node.x = Math.max(d.node.width / 2, d.node.x + dx / this.scale)
    d.node.y = Math.max(d.node.height / 2, d.node.y + dy / this.scale)
    d.x = event.clientX
    d.y = event.clientY
    place(d.node)
    this.resize()
    this.draw()
  }

  drop() {
    const d = this.dragging
    if (!d) return
    this.dragged = d.moved
    this.dragging = null
    if (d.moved) this.dispatch("moved", { detail: { id: d.id, x: Math.round(d.node.x), y: Math.round(d.node.y) } })
  }

  // A drag ends in a click on the node's link; don't follow it. A real click selects the node.
  click(event) {
    if (this.dragged) event.preventDefault()
    else this.nodeTargets.forEach(el => el === event.currentTarget ? el.setAttribute("aria-current", "true") : el.removeAttribute("aria-current"))
    this.dragged = false
  }

  link(event) {
    if (event.button !== 0) return
    const id = event.currentTarget.closest("[data-flow-target~='node']").dataset.id
    this.dragged = false
    this.linking = { id, from: anchor(this.graph.node(id), 1), x: event.clientX, y: event.clientY }
    event.currentTarget.setPointerCapture(event.pointerId)
  }

  stretch(event) {
    const l = this.linking
    if (!l) return
    const to = { x: l.from.x + (event.clientX - l.x) / this.scale, y: l.from.y + (event.clientY - l.y) / this.scale }
    this.draw()
    this.edgesTarget.insertAdjacentHTML("beforeend", `<path d="${curve([l.from, to])}" class="stroke-rocket" />`)
  }

  attach(event) {
    const l = this.linking
    if (!l) return
    this.linking = null
    // The press ends in a click on the node's link; don't follow it.
    this.dragged = true
    this.draw()
    const to = document.elementFromPoint(event.clientX, event.clientY)?.closest("[data-flow-target~='node']")
    if (to && this.element.contains(to) && to.dataset.id !== l.id) this.dispatch("linked", { detail: { from: l.id, to: to.dataset.id } })
  }

  // Fits the canvas to its nodes, and at least to the visible area so anything can be dropped anywhere.
  resize() {
    const nodes = this.graph.nodes().map(id => this.graph.node(id))
    const width = Math.max(this.element.clientWidth / this.scale, ...nodes.map(n => n.x + n.width / 2 + 4))
    const height = Math.max(this.element.clientHeight / this.scale, ...nodes.map(n => n.y + n.height / 2 + 4))
    Object.assign(this.canvasTarget.style, { width: `${width}px`, height: `${height}px` })
  }

  draw() {
    const g = this.graph
    this.edgesTarget.innerHTML = g.edges().map(e => {
      const source = g.node(e.v), target = g.node(e.w), from = anchor(source, 1), to = anchor(target, -1)
      // dagre doubles the ranks to fit edge labels: keep only the bends at node ranks. Dragging a node drops its edges' bends.
      const via = source.moved || target.moved ? [] : g.edge(e).points.slice(1, -1).filter((_, i) => i % 2)
      // It routes through node centres; lift the bends to icon height, blending from source to target.
      const lift = t => (from.y - source.y) * (1 - t) + (to.y - target.y) * t
      const points = [from, ...via.map((p, i) => ({ x: p.x, y: p.y + lift((i + 1) / (via.length + 1)) })), to]
      return `<path d="${curve(points)}" />`
    }).join("")
  }
}

function place({ el, x, y, width, height }) {
  el.style.left = `${x - width / 2}px`
  el.style.top = `${y - height / 2}px`
}

// Where edges attach on a node's right (side 1) or left (side -1) side.
function anchor(node, side) {
  return { x: node.x + side * node.width / 2, y: node.y - node.height / 2 + node.anchor }
}

// Bézier segments through the points, horizontal at each one, so a left-to-right flow never overshoots.
function curve(points) {
  return points.map((p, i) => {
    if (i === 0) return `M${p.x},${p.y}`
    const b = points[i - 1], mx = (b.x + p.x) / 2
    return `C${mx},${b.y} ${mx},${p.y} ${p.x},${p.y}`
  }).join("")
}
