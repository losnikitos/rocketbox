import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import dagre from "@dagrejs/dagre"

// Lays out the node targets left to right and draws the edges ([from id, to id, { id, path, frame, current }]) as curved
// arrows; an edge with a path is clicked like a node's link.
// Nodes with data-x/data-y (their centre) stay there instead. Nodes can be dragged around (flow:moved with the new
// centre, or flow:copied with a copy's when Alt is held at the grab) and the canvas pinch-zoomed or dragged to pan; zoom and scroll
// survive reloads of the page.
// Dragging from a node's [data-flow-handle] onto another node dispatches flow:linked with both ids; dragging an end of
// the selected edge (one with an id) onto another node dispatches it with the edge's id too. Into a node with slots
// (ports with data-slot) it carries the slot of the port under the pointer, else the first one free. Output targets (with
// data-v and data-w) sit on the middle of their edge.
export default class extends Controller {
  static targets = ["canvas", "node", "edges", "ends", "output"]
  static values = { edges: Array }

  connect() {
    this.scale = 1
    const g = this.graph = new dagre.graphlib.Graph()
    g.setGraph({ rankdir: "LR", nodesep: 24, ranksep: 72, marginx: 4, marginy: 4 })
    g.setDefaultEdgeLabel(() => ({}))
    // Edges attach at the middle of the node's first child (a folder's icon, a recipe's whole box), not the label below,
    // or, coming in, at its [data-flow-input] ports if it has them.
    this.nodeTargets.forEach(el => {
      const first = el.firstElementChild, anchor = first.offsetHeight / 2
      el.querySelectorAll("[data-flow-handle]").forEach(it => it.style.top = `${anchor}px`)
      el.querySelectorAll("[data-flow-play]").forEach(it => Object.assign(it.style, { top: `${first.offsetTop}px`, left: `${first.offsetLeft}px` }))
      // Ports sit in a column flush with the node's top.
      const ports = [...el.querySelectorAll("[data-flow-input]")]
      const inputs = ports.map(port => port.offsetTop + port.offsetHeight / 2), slots = ports.map(port => port.dataset.slot).filter(Boolean)
      g.setNode(el.dataset.id, { el, width: el.offsetWidth, height: el.offsetHeight, anchor, inputs, slots })
    })
    this.edgesValue.forEach(([from, to, edge]) => g.setEdge(from, to, { ...edge }))
    dagre.layout(g)

    g.nodes().forEach(id => {
      const node = g.node(id), { x, y } = node.el.dataset
      if (x) Object.assign(node, { x: +x, y: +y, moved: true })
      place(node)
    })
    const view = JSON.parse(sessionStorage.getItem(this.key) || "null")
    if (view) this.canvasTarget.style.zoom = this.scale = view.scale
    this.resize(view?.left, view?.top)
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
    const left = x * this.scale - mx, top = y * this.scale - my
    this.resize(left, top)
    Object.assign(this.element, { scrollLeft: left, scrollTop: top })
    this.remember()
  }

  remember() {
    sessionStorage.setItem(this.key, JSON.stringify({ scale: this.scale, left: this.element.scrollLeft, top: this.element.scrollTop }))
  }

  get key() { return `flow:${location.pathname}` }
  // A press on the empty canvas (not a node, an edge or the scrollbars) drags the view around.
  pan(event) {
    if (event.button !== 0 || !this.canvasTarget.contains(event.target) || event.target.closest("[data-flow-target~='node'], [data-v]")) return
    this.dragged = false
    this.panning = { x: event.clientX, y: event.clientY, moved: false }
    this.element.setPointerCapture(event.pointerId)
  }

  slide(event) {
    const p = this.panning
    if (!p) return
    const dx = event.clientX - p.x, dy = event.clientY - p.y
    if (!p.moved && Math.hypot(dx, dy) < 4) return
    p.moved = true
    this.element.scrollLeft -= dx
    this.element.scrollTop -= dy
    p.x = event.clientX
    p.y = event.clientY
  }

  // A pan ends in a click on the canvas; don't clear the selection.
  stop() {
    if (!this.panning) return
    this.dragged = this.panning.moved
    this.panning = null
  }

  // With Alt held a copy of the node is dragged away instead, the node staying put.
  grab(event) {
    if (event.button !== 0) return
    const el = event.currentTarget, id = el.dataset.id, node = this.graph.node(id), copy = event.altKey
    this.dragged = false
    this.dragging = { id, node: copy ? { ...node, el: ghost(el) } : node, copy, x: event.clientX, y: event.clientY, moved: false }
    el.setPointerCapture(event.pointerId)
    this.dragging.node.el.style.zIndex = this.z = (this.z || 0) + 1
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

  drop(event) {
    const d = this.dragging
    if (!d) return
    this.dragged = d.moved
    this.dragging = null
    if (d.copy && !d.moved) d.node.el.remove()
    if (d.moved) this.dispatch(d.copy ? "copied" : "moved", { detail: { id: d.id, x: Math.round(d.node.x), y: Math.round(d.node.y) } })
  }

  // A drag ends in a click on the node's link; don't follow it. A real click selects the node.
  click(event) {
    if (this.dragged) event.preventDefault()
    else this.select(event.currentTarget)
    this.dragged = false
  }

  pick(event) {
    const hit = event.target.closest("[data-v]")
    if (!hit) return
    const edge = { v: hit.dataset.v, w: hit.dataset.w }, { path, frame } = this.graph.edge(edge)
    this.select(null, edge)
    Turbo.visit(path, { frame, action: "advance" })
  }

  // A click on the canvas itself, not at the end of a drag, clears the selection (flow:cleared).
  clear(event) {
    const dragged = this.dragged
    this.dragged = false
    if (dragged || event.target.closest("[data-flow-target~='node'], [data-v]")) return
    if (!this.element.querySelector("[aria-current]") && !this.graph.edges().some(e => this.graph.edge(e).current)) return
    this.select(null)
    this.dispatch("cleared")
  }

  // Marks one node element or edge ({ v, w }) as the selected one.
  select(node, edge) {
    this.nodeTargets.forEach(el => el === node ? el.setAttribute("aria-current", "true") : el.removeAttribute("aria-current"))
    this.graph.edges().forEach(e => this.graph.edge(e).current = e.v === edge?.v && e.w === edge?.w)
    this.draw()
  }

  // A new arrow out of a node's handle.
  link(event) {
    const id = event.currentTarget.closest("[data-flow-target~='node']").dataset.id
    this.reach(event, { fixed: id, side: 1, start: anchor(this.graph.node(id), 1) })
  }

  // One end of the selected edge, moved to another node while the other end stays.
  regrab(event) {
    const { v, w, end } = event.currentTarget.dataset, edge = { v, w }, [from, to] = this.anchors(edge)
    this.reach(event, end === "to" ? { fixed: v, side: 1, start: from, edge } : { fixed: w, side: -1, start: to, edge })
  }

  // side 1: the fixed node is the source and the loose end its target; -1 the other way round.
  reach(event, linking) {
    if (event.button !== 0) return
    this.dragged = false
    this.linking = linking
    event.currentTarget.setPointerCapture(event.pointerId)
    // Faded, not redrawn or hidden, so the dragged knob keeps the pointer capture.
    this.endsTarget.classList.add("opacity-0")
    this.draw()
  }

  // The loose end snaps to a node it can attach to, which lights up, or follows the pointer.
  stretch(event) {
    const l = this.linking
    if (!l) return
    const node = this.droppable(event)
    this.nodeTargets.forEach(el => el.toggleAttribute("data-flow-drop", el === node?.el))
    const port = node && l.side > 0 ? node.inputs[node.slots.indexOf(this.slotAt(event, node, l.edge))] : undefined
    const loose = node ? anchor(node, -l.side, port) : this.point(event)
    this.draw()
    this.edgesTarget.insertAdjacentHTML("beforeend", `<path d="${curve(l.side > 0 ? [l.start, loose] : [loose, l.start])}" class="stroke-rocket" />`)
  }

  // Dropped on a node it can attach to: flow:linked with both ids, and the edge's id when one was moved. Anywhere else
  // it snaps back.
  attach(event) {
    const l = this.linking
    if (!l) return
    const node = this.droppable(event)
    this.linking = null
    // The press ends in a click on the node's link; don't follow it.
    this.dragged = true
    this.nodeTargets.forEach(el => el.removeAttribute("data-flow-drop"))
    this.draw()
    if (!node) return
    const [from, to] = l.side > 0 ? [l.fixed, node.el.dataset.id] : [node.el.dataset.id, l.fixed]
    const slot = l.side > 0 ? this.slotAt(event, node, l.edge) : l.edge && this.graph.edge(l.edge).slot
    this.dispatch("linked", { detail: { id: l.edge && this.graph.edge(l.edge).id, from, to, slot } })
  }

  // The node under the pointer the loose end may attach to, mirroring WorkflowEdge: not the fixed node, a step at one
  // end, no arrow into a source (data-source), and not connected that way already, unless by the edge being moved.
  droppable({ clientX, clientY }) {
    const el = document.elementFromPoint(clientX, clientY)?.closest("[data-flow-target~='node']")
    if (!el || !this.element.contains(el)) return
    const g = this.graph, { fixed, side, edge } = this.linking, [v, w] = side > 0 ? [fixed, el.dataset.id] : [el.dataset.id, fixed]
    if (v === w || (g.hasEdge(v, w) && !(edge?.v === v && edge?.w === w)) || "source" in g.node(w).el.dataset) return
    if (!("step" in g.node(v).el.dataset || "step" in g.node(w).el.dataset)) return
    return g.node(el.dataset.id)
  }

  // The slot an arrow dropped on `node` goes into: the port's under the pointer, else the first no other arrow
  // (besides `moving`) goes into, else the first; none for a node without slots.
  slotAt({ clientX, clientY }, node, moving) {
    if (!node.slots.length) return
    const port = document.elementFromPoint(clientX, clientY)?.closest("[data-slot]")
    if (port && node.el.contains(port)) return port.dataset.slot
    const g = this.graph, taken = g.inEdges(node.el.dataset.id).filter(e => !(e.v === moving?.v && e.w === moving?.w)).map(e => g.edge(e).slot)
    return node.slots.find(slot => !taken.includes(slot)) ?? node.slots[0]
  }

  // The pointer in canvas coordinates.
  point({ clientX, clientY }) {
    const box = this.element.getBoundingClientRect()
    return { x: (this.element.scrollLeft + clientX - box.left) / this.scale, y: (this.element.scrollTop + clientY - box.top) / this.scale }
  }

  // Where an edge leaves its source and enters its target. Edges in take their slot's port, or else the target's ports
  // top to bottom in their sources' order, so they don't cross.
  anchors({ v, w }) {
    const g = this.graph, target = g.node(w)
    const port = target.slots.length ? target.slots.indexOf(g.edge(v, w).slot)
      : g.inEdges(w).map(i => i.v).sort((a, b) => g.node(a).y - g.node(b).y).indexOf(v)
    return [anchor(g.node(v), 1), anchor(target, -1, target.inputs[port])]
  }

  // Fits the canvas to its nodes, and at least to the area visible when scrolled to `left`, `top`, so anything can be
  // dropped anywhere and the scroll isn't clamped.
  resize(left = this.element.scrollLeft, top = this.element.scrollTop) {
    const nodes = this.graph.nodes().map(id => this.graph.node(id))
    const width = Math.max((left + this.element.clientWidth) / this.scale, ...nodes.map(n => n.x + n.width / 2 + 4))
    const height = Math.max((top + this.element.clientHeight) / this.scale, ...nodes.map(n => n.y + n.height / 2 + 4))
    Object.assign(this.canvasTarget.style, { width: `${width}px`, height: `${height}px` })
  }

  draw() {
    const g = this.graph, moving = this.linking?.edge
    this.edgesTarget.innerHTML = g.edges().filter(e => !(e.v === moving?.v && e.w === moving?.w)).map(e => {
      const source = g.node(e.v), target = g.node(e.w), [from, to] = this.anchors(e)
      // dagre doubles the ranks to fit edge labels: keep only the bends at node ranks. Dragging a node drops its edges' bends.
      const via = source.moved || target.moved ? [] : g.edge(e).points.slice(1, -1).filter((_, i) => i % 2)
      // It routes through node centres; lift the bends to icon height, blending from source to target.
      const lift = t => (from.y - source.y) * (1 - t) + (to.y - target.y) * t
      const points = [from, ...via.map((p, i) => ({ x: p.x, y: p.y + lift((i + 1) / (via.length + 1)) })), to]
      g.edge(e).middle = middle(points)
      const d = curve(points), { path, current } = g.edge(e), line = `<path d="${d}" class="${current ? "stroke-rocket" : path ? "group-hover:stroke-ink-900/50" : ""}" />`
      // A wide invisible stroke makes the thin dashed line easy to click.
      return path ? `<g data-v="${e.v}" data-w="${e.w}" class="group cursor-pointer"><path d="${d}" stroke="transparent" stroke-width="12" stroke-dasharray="none" />${line}</g>` : line
    }).join("")
    this.outputTargets.forEach(el => {
      const { x, y } = g.edge(el.dataset.v, el.dataset.w).middle
      Object.assign(el.style, { left: `${x}px`, top: `${y}px` })
    })
    if (this.linking) return
    // Knobs on the selected edge's ends, above every node dragged to the front.
    const selected = g.edges().find(e => g.edge(e).current && g.edge(e).id)
    this.endsTarget.innerHTML = selected ? this.anchors(selected).map(({ x, y }, i) =>
      `<span data-v="${selected.v}" data-w="${selected.w}" data-end="${i ? "to" : "from"}" title="Drag to another node" style="left:${x}px;top:${y}px"
             data-action="pointerdown->flow#regrab:stop pointermove->flow#stretch:stop pointerup->flow#attach:stop pointercancel->flow#attach:stop"
             class="pointer-events-auto absolute size-4 -translate-1/2 cursor-grab touch-none rounded-full border-2 border-rocket bg-white hover:bg-rocket/10 active:cursor-grabbing"></span>`).join("") : ""
    this.endsTarget.style.zIndex = (this.z || 0) + 1
    this.endsTarget.classList.remove("opacity-0")
  }
}

// A stand-in for an Alt-dragged node's copy until the page re-renders with the saved one; not a node target.
function ghost(el) {
  const copy = el.cloneNode(true)
  ;["id", "data-flow-target", "data-action", "aria-current"].forEach(name => copy.removeAttribute(name))
  el.after(copy)
  return copy
}

function place({ el, x, y, width, height }) {
  el.style.left = `${x - width / 2}px`
  el.style.top = `${y - height / 2}px`
}

// Where edges attach on a node's right (side 1) or left (side -1) side, `offset` down from its top.
function anchor(node, side, offset = node.anchor) {
  return { x: node.x + side * node.width / 2, y: node.y - node.height / 2 + offset }
}

// The point halfway through curve(points): the middle point, or between the middle two, where their symmetric segment
// passes at its halfway mark.
function middle(points) {
  const i = points.length / 2
  if (points.length % 2) return points[Math.floor(i)]
  const a = points[i - 1], b = points[i]
  return { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }
}

// Bézier segments through the points, horizontal at each one, so a left-to-right flow never overshoots.
function curve(points) {
  return points.map((p, i) => {
    if (i === 0) return `M${p.x},${p.y}`
    const b = points[i - 1], mx = (b.x + p.x) / 2
    return `C${mx},${b.y} ${mx},${p.y} ${p.x},${p.y}`
  }).join("")
}
