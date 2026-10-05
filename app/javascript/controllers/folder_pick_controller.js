import { Controller } from "@hotwired/stimulus"

let count = 0

// Folder dropdown: a hidden input, a trigger mirroring the picked option, options in a popover.
// Anchors are wired here, not by id, so a cloned picker (another recipe input) gets its own popover.
export default class extends Controller {
  static targets = ["input", "trigger", "preview", "popover", "option", "placeholder", "search", "separator"]

  connect() {
    const anchor = `--folder-pick-${++count}`
    this.triggerTarget.popoverTargetElement = this.popoverTarget
    this.triggerTarget.style.anchorName = anchor
    this.popoverTarget.style.positionAnchor = anchor
    this.show()
  }

  pick({ currentTarget }) {
    this.inputTarget.value = currentTarget.value
    this.show()
    this.popoverTarget.hidePopover()
  }

  opened({ newState }) {
    if (newState !== "open") return
    this.searchTarget.value = ""
    this.filter()
    this.searchTarget.focus()
  }

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()
    this.optionTargets.forEach((option) => (option.hidden = !option.textContent.toLowerCase().includes(query)))
    this.separatorTargets.forEach((separator) => (separator.hidden = query !== ""))
  }

  // Enter would otherwise submit the surrounding form.
  pickFirst(event) {
    event.preventDefault()
    this.optionTargets.find((option) => !option.hidden)?.click()
  }

  show() {
    const option = this.optionTargets.find((option) => option.value === this.inputTarget.value)
    this.optionTargets.forEach((each) => (each.ariaCurrent = each === option ? "true" : null))
    this.previewTarget.replaceChildren((option?.firstElementChild ?? this.placeholderTarget.content).cloneNode(true))
  }
}
