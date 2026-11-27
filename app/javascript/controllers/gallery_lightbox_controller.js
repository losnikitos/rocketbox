import { Controller } from "@hotwired/stimulus"

// Arrow keys: cycle open popover lightboxes among panel targets, or visit prev/next URLs on a show page.
export default class extends Controller {
  static targets = ["panel"]
  static values = { prev: String, next: String }

  connect() {
    this.onKey = this.onKey.bind(this)
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
  }

  onKey(event) {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return
    const open = this.panelTargets.find((el) => el.matches(":popover-open"))
    if (open) {
      event.preventDefault()
      const i = this.panelTargets.indexOf(open)
      const next = event.key === "ArrowRight"
        ? this.panelTargets[(i + 1) % this.panelTargets.length]
        : this.panelTargets[(i - 1 + this.panelTargets.length) % this.panelTargets.length]
      open.hidePopover()
      next.showPopover()
      return
    }

    const url = event.key === "ArrowRight" ? this.nextValue : this.prevValue
    if (!url) return
    event.preventDefault()
    window.Turbo ? Turbo.visit(url) : (window.location.href = url)
  }
}
