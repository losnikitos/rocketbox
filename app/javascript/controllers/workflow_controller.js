import { Controller } from "@hotwired/stimulus"

// The workflow editor around the flow canvas: saves where nodes are dragged to (flow:moved), submits the arrows drawn
// between them (flow:linked), and adds palette items dropped on the canvas there, or clicked, in the middle of the view.
export default class extends Controller {
  static targets = ["add", "x", "y", "connect", "from", "to", "tab"]
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

  link({ detail: { from, to } }) {
    this.fromTarget.value = from
    this.toTarget.value = to
    this.connectTarget.requestSubmit()
  }

  tab({ currentTarget }) {
    this.tabTargets.forEach(tab => {
      tab.setAttribute("aria-selected", tab === currentTarget)
      document.getElementById(tab.getAttribute("aria-controls")).hidden = tab !== currentTarget
    })
  }

  pick(event) {
    this.picked = event.currentTarget
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
