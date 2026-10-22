import { Controller } from "@hotwired/stimulus"

// Opens a log on its newest entry. Scrolls the element, then the page, so a short mobile thread still lands at the end.
export default class extends Controller {
  connect() {
    const last = this.element.lastElementChild
    if (!last) return

    this.element.scrollTop = this.element.scrollHeight
    last.scrollIntoView({ block: "end" })
  }
}
