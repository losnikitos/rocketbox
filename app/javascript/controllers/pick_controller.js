import { Controller } from "@hotwired/stimulus"

let count = 0

// Searchable dropdown: a hidden input, a trigger mirroring the picked option, options in a popover.
// With `multiple`, options are labels holding a checkbox and the trigger mirrors every checked one; the popover stays open.
// Anchors are wired here, not by id, so a cloned picker (another recipe input) gets its own popover.
export default class extends Controller {
  static targets = ["input", "trigger", "preview", "popover", "option", "placeholder", "search", "separator"]
  static values = { multiple: Boolean }

  connect() {
    const anchor = `--pick-${++count}`
    this.triggerTarget.popoverTargetElement = this.popoverTarget
    this.triggerTarget.style.anchorName = anchor
    this.popoverTarget.style.positionAnchor = anchor
    this.show()
  }

  pick({ currentTarget }) {
    this.inputTarget.value = currentTarget.value
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
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
    if (this.multipleValue) return this.#preview(this.optionTargets.filter((option) => option.querySelector("input").checked))

    const option = this.optionTargets.find((option) => option.value === this.inputTarget.value)
    this.optionTargets.forEach((each) => (each.ariaCurrent = each === option ? "true" : null))
    this.#preview(option ? [option] : [])
  }

  #preview(options) {
    const chips = options.map((option) => option.firstElementChild.cloneNode(true))
    this.previewTarget.replaceChildren(...(chips.length ? chips : [this.placeholderTarget.content.cloneNode(true)]))
  }
}
