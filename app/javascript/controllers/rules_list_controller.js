import { Controller } from "@hotwired/stimulus"

// Ordered post rules: each row is a <select name="post[rules][]">; add clones the blank template.
export default class extends Controller {
  static targets = ["list", "template"]

  add() {
    this.listTarget.append(this.templateTarget.content.cloneNode(true))
  }

  remove({ currentTarget }) {
    currentTarget.closest("[data-rules-list-row]").remove()
  }

  up({ currentTarget }) {
    const row = currentTarget.closest("[data-rules-list-row]")
    row.previousElementSibling?.before(row)
  }

  down({ currentTarget }) {
    const row = currentTarget.closest("[data-rules-list-row]")
    row.nextElementSibling?.after(row)
  }
}
