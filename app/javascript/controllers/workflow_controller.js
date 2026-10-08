import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The workflow editor around the flow canvas: saves where nodes are dragged to (flow:moved), copies a node Alt-dragged
// to the drop point (flow:copied), submits the arrows drawn between them or moved to other nodes (flow:linked), and adds
// palette items or a folder's media from the inspector dropped on the canvas there, or clicked, in the middle of the view.
export default class extends Controller {
  static targets = ["add", "x", "y", "connect", "edge", "from", "to", "slot", "copy", "copyNode", "copyX", "copyY", "tab", "remove", "item"]
  static values = { url: String }

  async move({ detail: { id, x, y } }) {
    const body = new FormData()
    Object.entries({ id, x, y }).forEach(([key, value]) => body.append(`workflow[nodes_attributes][0][${key}]`, value))
    const response = await fetch(this.urlValue, {
      method: "PATCH", body,
      headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content }
    }).catch(() => null)
    if (!response?.ok) alert("Couldn't save where the node was moved. Reload and try again.")
  }

  clear() {
    Turbo.visit(this.urlValue, { frame: "inspector", action: "advance" })
  }

  link({ detail: { id, from, to, slot } }) {
    this.edgeTarget.value = id ?? ""
    this.fromTarget.value = from
    this.toTarget.value = to
    this.slotTarget.value = slot ?? ""
    this.connectTarget.requestSubmit()
  }

  copy({ detail: { id, x, y } }) {
    this.copyNodeTarget.value = id
    this.copyXTarget.value = x
    this.copyYTarget.value = y
    this.copyTarget.requestSubmit()
  }

  // Delete (Backspace on a Mac) removes the selected node or connection, unless typing in a field.
  remove(event) {
    if (!["Delete", "Backspace"].includes(event.key) || event.repeat || !this.hasRemoveTarget) return
    if (event.target.isContentEditable || event.target.closest("input, textarea, select")) return
    event.preventDefault()
    this.removeTarget.click()
  }

  // Mode and run links keep the selected node or connection, which the inspector frame puts in the page's URL.
  keep({ currentTarget: link }) {
    const url = new URL(link.href), here = new URLSearchParams(location.search)
    ;["node", "edge"].forEach(key => here.has(key) ? url.searchParams.set(key, here.get(key)) : url.searchParams.delete(key))
    link.href = url
  }

  tab({ currentTarget }) {
    this.tabTargets.forEach(tab => {
      tab.setAttribute("aria-selected", tab === currentTarget)
      document.getElementById(tab.getAttribute("aria-controls")).hidden = tab !== currentTarget
    })
  }

  // Items in the search's own tab whose name or title (a folder's path, a transformation's prompt) holds the query.
  filter({ target }) {
    const query = target.value.trim().toLowerCase(), panel = target.closest("[role='tabpanel']")
    this.itemTargets.filter(item => panel.contains(item))
      .forEach(item => item.hidden = !`${item.textContent} ${item.title}`.toLowerCase().includes(query))
  }

  // Palette items are their own add buttons; a folder's media in the inspector holds one.
  pick(event) {
    const item = event.currentTarget
    this.picked = item.form ? item : item.querySelector("[form='workflow_add']")
    event.dataTransfer.setData("text/plain", this.picked.textContent.trim())
    event.dataTransfer.effectAllowed = "copy"
  }

  unpick() {
    this.picked = null
  }

  over(event) {
    if (!this.picked) return
    event.preventDefault()
    event.dataTransfer.dropEffect = "copy"
  }

  drop(event) {
    if (!this.picked) return
    event.preventDefault()
    this.point = event
    this.addTarget.requestSubmit(this.picked)
    this.picked = null
  }

  // Before an add: the drop point, or the middle of the view for a click, in canvas coordinates.
  place() {
    const flow = this.element.querySelector("[data-controller~='flow']"), box = flow.getBoundingClientRect()
    const scale = parseFloat(flow.querySelector("[data-flow-target='canvas']").style.zoom) || 1
    const { clientX, clientY } = this.point || { clientX: box.left + box.width / 2, clientY: box.top + box.height / 2 }
    this.point = null
    this.xTarget.value = Math.round((flow.scrollLeft + clientX - box.left) / scale)
    this.yTarget.value = Math.round((flow.scrollTop + clientY - box.top) / scale)
  }
}
