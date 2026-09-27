import { Controller } from "@hotwired/stimulus"

// ponytail: polls instead of Action Cable — dev cable is async and jobs run in bin/jobs; upgrade = solid_cable in dev + broadcast_refresh_to
export default class extends Controller {
  static targets = ["url", "copyLabel"]

  connect() {
    this.refresh = () => { if (!document.hidden) Turbo.visit(location.href, { action: "replace" }) }
    this.timer = setInterval(this.refresh, 3000)
    document.addEventListener("visibilitychange", this.refresh)
  }

  disconnect() {
    clearInterval(this.timer)
    document.removeEventListener("visibilitychange", this.refresh)
  }

  async copy() {
    await navigator.clipboard.writeText(this.urlTarget.value)
    this.copyLabelTarget.textContent = "Copied"
    setTimeout(() => { this.copyLabelTarget.textContent = "Copy" }, 2000)
  }
}
