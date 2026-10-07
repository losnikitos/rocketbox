import { Controller } from "@hotwired/stimulus"

let count = 0

// Searchable dropdown: a hidden input, a trigger mirroring the picked option, options in a popover.
// With `multiple`, options are labels holding a checkbox and the trigger mirrors every checked one; the popover stays open.
// With `wide`, the popover anchors to the picker's parent (the bordered row it sits in) instead of the trigger.
// Anchors are wired here, not by id, so a cloned picker (another recipe input) gets its own popover.
export default class extends Controller {
  static targets = ["input", "trigger", "preview", "popover", "option", "placeholder", "search", "separator", "create", "createName", "blank"]
  static values = { multiple: Boolean, wide: Boolean, createUrl: String }

  connect() {
    const anchor = `--pick-${++count}`
    this.triggerTarget.popoverTargetElement = this.popoverTarget
    const anchored = this.wideValue ? this.element.parentElement : this.triggerTarget
    anchored.style.anchorName = anchor
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
    const query = this.searchTarget.value.trim().toLowerCase().replace(/^#/, "")
    this.optionTargets.forEach((option) => (option.hidden = !option.textContent.toLowerCase().includes(query)))
    this.separatorTargets.forEach((separator) => (separator.hidden = query !== ""))
    if (!this.hasCreateTarget) return
    this.createNameTarget.textContent = query
    this.createTarget.hidden = !query || this.optionTargets.some((option) => this.#name(option) === query)
  }

  // Enter would otherwise submit the surrounding form.
  pickFirst(event) {
    event.preventDefault()
    ;[...this.optionTargets, ...this.createTargets].find((option) => !option.hidden)?.click()
  }

  // Creates the searched name on the server, adds it as an option from the blank template and picks it.
  async create() {
    const response = await fetch(this.createUrlValue, {
      method: "POST",
      body: new URLSearchParams({ name: this.createNameTarget.textContent }),
      headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content }
    })
    const { id, name, error } = await response.json()
    if (!response.ok) return alert(error)

    const option = this.blankTarget.content.firstElementChild.cloneNode(true)
    ;(option.querySelector("input") ?? option).value = id
    option.querySelector("span > span").append(name)
    this.createTarget.before(option)
    this.filter()
    option.click()
  }

  show() {
    if (this.multipleValue) return this.#preview(this.optionTargets.filter((option) => option.querySelector("input").checked))

    const option = this.optionTargets.find((option) => option.value === this.inputTarget.value)
    this.optionTargets.forEach((each) => (each.ariaCurrent = each === option ? "true" : null))
    this.#preview(option ? [option] : [])
  }

  // The option's chip label (a tag pill is the chip's first span), or undefined for plain options like "Any tag".
  #name(option) {
    return option.querySelector("span > span")?.textContent.trim()
  }

  #preview(options) {
    const chips = options.map((option) => option.firstElementChild.cloneNode(true))
    this.previewTarget.replaceChildren(...(chips.length ? chips : [this.placeholderTarget.content.cloneNode(true)]))
  }
}
