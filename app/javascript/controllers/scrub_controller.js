import { Controller } from "@hotwired/stimulus"

// Hover scrubs through stacked slides by mouse X (e.g. prompt example covers).
export default class extends Controller {
  static targets = ["slide"]

  scrub(event) {
    const rect = this.element.getBoundingClientRect()
    const count = this.slideTargets.length
    this.show(Math.min(Math.max(Math.floor(((event.clientX - rect.left) / rect.width) * count), 0), count - 1))
  }

  reset() {
    this.show(0)
  }

  show(index) {
    this.slideTargets.forEach((slide, i) => slide.classList.toggle("hidden", i !== index))
  }
}
