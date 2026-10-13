import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import dagre from "@dagrejs/dagre"

// Where nodes were dragged to, by id: a refresh fetched before the move was saved still has them where they were, and
// replaces this controller with a new one.
const placed = {}

// Places the node targets at their data-x/data-y (their centre) and draws the edges ([from id, to id, { id, path, frame, current, available }]) as curved
// arrows, solid green when available (media ready to go along them); an edge with a path is clicked like a node's link.
// Nodes can be dragged anywhere (flow:moved with the new centres, or flow:copied with a copy's when Alt is held at the
// grab) and the canvas pinch-zoomed or scrolled to pan; zoom and pan survive reloads of the page. Double-clicking a node
// with data-open opens that URL in a new tab. Dragging the empty canvas selects the nodes a rectangle touches; dragging one of them moves them all.
// Dragging from a node's [data-flow-handle] onto another node dispatches flow:linked with both ids; dragging an end of
// the selected edge (one with an id) onto another node dispatches it with the edge's id too. Output targets (with
// data-v and data-w) sit on the middle of their edge.
export default class extends Controller {
  static targets = ["canvas", "node", "edges", "ends", "output", "marquee"]
  static values = { edges: Array }

  connect() {
    const g = this.graph = new dagre.graphlib.Graph()
    g.setDefaultEdgeLabel(() => ({}))
    // Edges attach at the middle of the node's first child (a folder's icon, a step's card), not the label below,
    // or, coming in, at its [data-flow-input] ports if it has them.
    this.nodeTargets.forEach(el => {
      const first = el.firstElementChild, anchor = first.offsetHeight / 2, id = el.dataset.id
      el.querySelectorAll("[data-flow-handle]").forEach(it => it.style.top = `${anchor}px`)
      el.querySelectorAll("[data-flow-play]").forEach(it => Object.assign(it.style, { top: `${first.offsetTop}px`, left: `${first.offsetLeft}px` }))
      // Ports sit in a column flush with the node's top.
      const inputs = [...el.querySelectorAll("[data-flow-input]")].map(port => port.offsetTop + port.offsetHeight / 2)
      const { x, y } = placed[id] || el.dataset
      g.setNode(id, { el, x: +x, y: +y, width: el.offsetWidth, height: el.offsetHeight, anchor, inputs })
      place(g.node(id))
    })
    this.edgesValue.forEach(([from, to, edge]) => g.setEdge(from, to, { ...edge }))
    // First visit: the canvas's origin, or the top-left node if it's further up or left, a little in from the corner.
    const nodes = g.nodes().map(id => g.node(id))
    this.view = JSON.parse(sessionStorage.getItem(this.key) || "null") || {
      x: 40 - Math.min(0, ...nodes.map(n => n.x - n.width / 2)), y: 40 - Math.min(0, ...nodes.map(n => n.y - n.height / 2)), scale: 1
    }
    this.apply()
    this.draw()
    this.canvasTarget.classList.remove("invisible")
  }

  // Trackpad pinch arrives as a wheel event with ctrlKey (Chrome, Firefox); plain scrolling pans.
  wheel(event) {
    event.preventDefault()
    // Some mice scroll by lines (Firefox).
    const k = event.deltaMode ? 16 : 1
    if (event.ctrlKey) return this.zoom(this.view.scale * Math.exp(-event.deltaY * k / 100), event)
    this.view.x -= event.deltaX * k
    this.view.y -= event.deltaY * k
    this.apply()
  }

  // Safari sends pinch as gesture events with a scale relative to the gesture's start.
  gesture(event) {
    event.preventDefault()
    if (event.type === "gesturestart") this.gestureScale = this.view.scale
    else this.zoom(this.gestureScale * event.scale, event)
  }

  // Zooms to `scale`, keeping the canvas point under the pointer in place.
  zoom(scale, { clientX, clientY }) {
    const box = this.element.getBoundingClientRect(), { x, y } = this.point({ clientX, clientY })
    const s = Math.min(2, Math.max(0.2, scale))
    this.view = { x: clientX - box.left - x * s, y: clientY - box.top - y * s, scale: s }
    this.apply()
  }

  // Focus (Tab) and find-in-page still scroll the hidden overflow; pan by it instead.
  unscroll() {
    const { scrollLeft, scrollTop } = this.element
    if (!scrollLeft && !scrollTop) return
    this.view.x -= scrollLeft
    this.view.y -= scrollTop
    Object.assign(this.element, { scrollLeft: 0, scrollTop: 0 })
    this.apply()
  }

  // Pans and zooms the canvas, the dots with it, and remembers where for reloads.
  apply() {
    const { x, y, scale } = this.view
    this.canvasTarget.style.transform = `translate(${x}px, ${y}px) scale(${scale})`
    Object.assign(this.element.style, { backgroundSize: `${20 * scale}px ${20 * scale}px`, backgroundPosition: `${x}px ${y}px` })
    sessionStorage.setItem(this.key, JSON.stringify(this.view))
  }

  get key() { return `flow-view:${location.pathname}` }

  // A refresh (a run's step finishing) arriving mid-gesture waits for its end, so the canvas isn't replaced under the
  // pointer.
  hold(event) {
    if (!(this.dragging || this.linking || this.marquee)) return
    event.preventDefault()
    ;(this.held ||= []).push(event.detail.resume)
  }

  release() {
    this.held?.forEach(resume => resume())
    this.held = null
  }

  // A press on the empty canvas (not a node or an edge) drags a selection rectangle, which clears the selection first
  // (flow:cleared).
  lasso(event) {
    if (event.button !== 0 || event.target.closest("[data-flow-target~='node'], [data-v]")) return
    press(event)
    this.dragged = false
    this.element.setPointerCapture(event.pointerId)
    if (this.selected) {
      this.select(null)
      this.dispatch("cleared")
    }
    this.marquee = { start: this.point(event), moved: false }
  }

  // Selects the nodes the rectangle from the press to the pointer touches.
  sweep(event) {
    const m = this.marquee
    if (!m) return
    const a = m.start, b = this.point(event)
    if (!m.moved && Math.hypot(b.x - a.x, b.y - a.y) * this.view.scale < 4) return
    m.moved = true
    const left = Math.min(a.x, b.x), top = Math.min(a.y, b.y), right = Math.max(a.x, b.x), bottom = Math.max(a.y, b.y)
    Object.assign(this.marqueeTarget.style, { left: `${left}px`, top: `${top}px`, width: `${right - left}px`, height: `${bottom - top}px`, zIndex: (this.z || 0) + 1 })
    this.marqueeTarget.hidden = false
    this.nodeTargets.forEach(el => {
      const { x, y, width, height } = this.graph.node(el.dataset.id)
      mark(el, x + width / 2 > left && x - width / 2 < right && y + height / 2 > top && y - height / 2 < bottom)
    })
  }

  // A selection rectangle ends in a click on the canvas; don't clear the selection.
  stop() {
    if (!this.marquee) return
    this.dragged = this.marquee.moved
    this.marquee = null
    this.marqueeTarget.hidden = true
    this.release()
  }

  // A selected node drags every selected node along. With Alt held a copy of the node is dragged away instead, the node
  // staying put.
  grab(event) {
    if (event.button !== 0) return
    press(event)
    const el = event.currentTarget, id = el.dataset.id, node = this.graph.node(id), copy = event.altKey
    const nodes = copy ? [{ ...node, el: ghost(el) }]
      : el.hasAttribute("aria-current") ? this.nodeTargets.filter(it => it.hasAttribute("aria-current")).map(it => this.graph.node(it.dataset.id)) : [node]
    this.dragged = false
    this.dragging = { id, nodes, copy, x: event.clientX, y: event.clientY, moved: false }
    el.setPointerCapture(event.pointerId)
    nodes.forEach(n => n.el.style.zIndex = this.z = (this.z || 0) + 1)
  }

  drag(event) {
    const d = this.dragging
    if (!d) return
    if (!d.moved && Math.hypot(event.clientX - d.x, event.clientY - d.y) < 4) return
    d.moved = true
    const dx = (event.clientX - d.x) / this.view.scale, dy = (event.clientY - d.y) / this.view.scale
    d.nodes.forEach(n => {
      Object.assign(n, { x: n.x + dx, y: n.y + dy })
      place(n)
    })
    d.x = event.clientX
    d.y = event.clientY
    this.draw()
  }

  drop(event) {
    const d = this.dragging
    if (!d) return
    this.dragged = d.moved
    this.dragging = null
    if (d.moved) {
      const at = d.nodes.map(n => ({ id: n.el.dataset.id, x: Math.round(n.x), y: Math.round(n.y) }))
      if (d.copy) this.dispatch("copied", { detail: { ...at[0], id: d.id } })
      else {
        at.forEach(({ id, x, y }) => placed[id] = { x, y })
        this.dispatch("moved", { detail: { nodes: at } })
      }
    } else if (d.copy) d.nodes[0].el.remove()
    this.release()
  }

  // A drag ends in a click on the node's link; don't follow it. A real click selects the node.
  click(event) {
    if (this.dragged) event.preventDefault()
    else this.select(event.currentTarget)
    this.dragged = false
  }

  // A double-click opens the node's data-open, if any, in a new tab.
  open(event) {
    const url = event.currentTarget.dataset.open
    if (url) window.open(url, "_blank", "noopener")
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
    if (dragged || !this.selected || event.target.closest("[data-flow-target~='node'], [data-v]")) return
    this.select(null)
    this.dispatch("cleared")
  }

  get selected() {
    return this.element.querySelector("[aria-current]") || this.graph.edges().some(e => this.graph.edge(e).current)
  }

  // Marks one node element or edge ({ v, w }) as the selected one.
  select(node, edge) {
    this.nodeTargets.forEach(el => mark(el, el === node))
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
    press(event)
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
    const port = node && l.side > 0 ? node.inputs[this.others(node, l.edge).length] : undefined
    const loose = node ? anchor(node, -l.side, port) : this.point(event)
    this.draw()
    this.edgesTarget.insertAdjacentHTML("beforeend", `<path d="${l.side > 0 ? curve(l.start, loose) : curve(loose, l.start)}" class="stroke-rocket" />`)
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
    this.release()
    if (!node) return
    const [from, to] = l.side > 0 ? [l.fixed, node.el.dataset.id] : [node.el.dataset.id, l.fixed]
    this.dispatch("linked", { detail: { id: l.edge && this.graph.edge(l.edge).id, from, to } })
  }

  // The node under the pointer the loose end may attach to, mirroring WorkflowEdge: not the fixed node, a step at one
  // end, no arrow into a source (data-source), no note (data-note) at either end, the kind of items the start gives
  // (data-gives) one a step takes (data-takes) or a folder holds, and not connected that way already, unless by the
  // edge being moved.
  droppable({ clientX, clientY }) {
    const el = document.elementFromPoint(clientX, clientY)?.closest("[data-flow-target~='node']")
    if (!el || !this.element.contains(el)) return
    const g = this.graph, { fixed, side, edge } = this.linking, [v, w] = side > 0 ? [fixed, el.dataset.id] : [el.dataset.id, fixed]
    if (v === w || (g.hasEdge(v, w) && !(edge?.v === v && edge?.w === w)) || "source" in g.node(w).el.dataset) return
    if ([v, w].some(id => "note" in g.node(id).el.dataset)) return
    if (!("step" in g.node(v).el.dataset || "step" in g.node(w).el.dataset)) return
    const gives = g.node(v).el.dataset.gives, into = g.node(w).el.dataset
    if ("step" in into ? !into.takes?.split(" ").includes(gives) : into.gives !== gives) return
    return g.node(el.dataset.id)
  }

  // The arrows into `node` besides `moving`.
  others(node, moving) {
    return this.graph.inEdges(node.el.dataset.id).filter(e => !(e.v === moving?.v && e.w === moving?.w))
  }

  // The pointer in canvas coordinates.
  point({ clientX, clientY }) {
    const box = this.element.getBoundingClientRect(), { x, y, scale } = this.view
    return { x: (clientX - box.left - x) / scale, y: (clientY - box.top - y) / scale }
  }

  // Where an edge leaves its source and enters its target. Edges in take the target's ports top to bottom in their
  // sources' order, so they don't cross.
  anchors({ v, w }) {
    const g = this.graph, target = g.node(w)
    const port = g.inEdges(w).map(i => i.v).sort((a, b) => g.node(a).y - g.node(b).y).indexOf(v)
    return [anchor(g.node(v), 1), anchor(target, -1, target.inputs[port])]
  }

  draw() {
    const g = this.graph, moving = this.linking?.edge
    this.edgesTarget.innerHTML = g.edges().filter(e => !(e.v === moving?.v && e.w === moving?.w)).map(e => {
      const [from, to] = this.anchors(e), d = curve(from, to), { path, current, available } = g.edge(e)
      // curve() passes halfway between its ends at its halfway mark.
      g.edge(e).middle = { x: (from.x + to.x) / 2, y: (from.y + to.y) / 2 }
      const line = `<path d="${d}" ${available ? `stroke-dasharray="none"` : ""} class="${current ? "stroke-rocket" : available ? "stroke-signal-green group-hover:stroke-signal-green/70" : path ? "group-hover:stroke-ink-900/50" : ""}" />`
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

// A press neither focuses (Chrome scrolls a half-hidden focused link into view, jumping the canvas) nor selects text,
// but still blurs whatever had focus.
function press(event) {
  event.preventDefault()
  document.activeElement?.blur()
}

// A stand-in for an Alt-dragged node's copy until the page re-renders with the saved one; not a node target.
function ghost(el) {
  const copy = el.cloneNode(true)
  ;["id", "data-flow-target", "data-action", "aria-current"].forEach(name => copy.removeAttribute(name))
  el.after(copy)
  return copy
}

function mark(el, selected) {
  selected ? el.setAttribute("aria-current", "true") : el.removeAttribute("aria-current")
}

function place({ el, x, y, width, height }) {
  el.style.left = `${x - width / 2}px`
  el.style.top = `${y - height / 2}px`
}

// Where edges attach on a node's right (side 1) or left (side -1) side, `offset` down from its top.
function anchor(node, side, offset = node.anchor) {
  return { x: node.x + side * node.width / 2, y: node.y - node.height / 2 + offset }
}

// A Bézier from a to b, horizontal at both ends, so a left-to-right flow never overshoots.
function curve(a, b) {
  const mx = (a.x + b.x) / 2
  return `M${a.x},${a.y}C${mx},${a.y} ${mx},${b.y} ${b.x},${b.y}`
}
