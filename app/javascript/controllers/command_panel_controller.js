import { Controller } from "@hotwired/stimulus"

// Cmd/Ctrl+K or P (or the sidebar search button) opens a fuzzy-filtered list of section links.
export default class extends Controller {
  static targets = ["dialog", "search", "item", "empty"]

  hotkey(event) {
    if (!(event.metaKey || event.ctrlKey) || event.altKey || event.shiftKey) return
    if (!["k", "p"].includes(event.key.toLowerCase())) return

    event.preventDefault()
    this.dialogTarget.open ? this.close() : this.open()
  }

  open() {
    this.searchTarget.value = ""
    this.filter()
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()
    this.itemTargets.forEach((item) => (item.hidden = !this.fuzzyMatch(query, item.dataset.label.toLowerCase())))
    this.emptyTarget.hidden = this.visibleItems().length > 0
    this.highlight(0)
  }

  navigate(event) {
    const items = this.visibleItems()
    const index = items.findIndex((item) => item.hasAttribute("aria-selected"))

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      this.highlight(index + (event.key === "ArrowDown" ? 1 : -1))
    } else if (event.key === "Enter" && items[index]) {
      event.preventDefault()
      items[index].click()
    }
  }

  highlight(index) {
    const items = this.visibleItems()
    this.itemTargets.forEach((item) => item.removeAttribute("aria-selected"))
    if (!items.length) return

    const item = items[(index + items.length) % items.length]
    item.setAttribute("aria-selected", "true")
    item.scrollIntoView({ block: "nearest" })
  }

  visibleItems() {
    return this.itemTargets.filter((item) => !item.hidden)
  }

  // Query chars appear in order in the haystack.
  fuzzyMatch(query, haystack) {
    let qi = 0
    for (let i = 0; i < haystack.length && qi < query.length; i++) {
      if (haystack[i] === query[qi]) qi += 1
    }
    return qi === query.length
  }
}
