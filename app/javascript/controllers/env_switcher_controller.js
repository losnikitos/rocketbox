import { Controller } from "@hotwired/stimulus"

// Hold Alt, press Tab to pick an environment; release Alt to open the same path there.
export default class extends Controller {
  static targets = ["option"]

  keydown(event) {
    if (event.key === "Escape" && !this.element.hidden) {
      event.preventDefault()
      this.hide()
      return
    }

    if (!event.altKey || event.key !== "Tab") return
    if (this.isEditable(event.target)) return

    event.preventDefault()

    if (this.element.hidden) {
      this.select(this.optionTargets.findIndex((option) => this.hostOf(option) === window.location.host) + 1)
      this.element.hidden = false
    } else {
      this.select(this.selectedIndex + 1)
    }
  }

  keyup(event) {
    if (this.element.hidden) return
    if (event.key !== "Alt" && event.altKey) return

    const origin = this.optionTargets[this.selectedIndex]?.dataset.origin
    this.hide()
    if (!origin || new URL(origin).host === window.location.host) return

    const { pathname, search, hash } = window.location
    window.location.href = `${origin}${pathname}${search}${hash}`
  }

  hide() {
    this.element.hidden = true
  }

  select(index) {
    this.selectedIndex = index % this.optionTargets.length
    this.optionTargets.forEach((option, i) => option.setAttribute("aria-selected", i === this.selectedIndex))
  }

  hostOf(option) {
    return new URL(option.dataset.origin).host
  }

  isEditable(target) {
    return target instanceof Element && (target.isContentEditable || target.matches("input, textarea, select"))
  }
}
