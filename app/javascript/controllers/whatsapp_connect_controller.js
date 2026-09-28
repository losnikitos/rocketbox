import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["url", "copyLabel"]

  async copy() {
    await navigator.clipboard.writeText(this.urlTarget.value)
    this.copyLabelTarget.textContent = "Copied"
    setTimeout(() => { this.copyLabelTarget.textContent = "Copy" }, 2000)
  }
}
