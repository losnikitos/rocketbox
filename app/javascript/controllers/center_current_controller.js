import { Controller } from "@hotwired/stimulus"

// Scrolls a horizontal strip so its aria-current item sits in the middle.
export default class extends Controller {
  connect() {
    const current = this.element.querySelector("[aria-current]")
    if (current) this.element.scrollLeft = current.offsetLeft - (this.element.clientWidth - current.offsetWidth) / 2
  }
}
