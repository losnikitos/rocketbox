import { Controller } from "@hotwired/stimulus"

// Picks up to `max` options in a popover; the trigger mirrors the checked ones. Radios close it on pick; checkboxes
// stay open to toggle several, a pick past `max` unchecking the first other one.
export default class extends Controller {
  static targets = ["preview", "popover", "option"]
  static values = { max: { type: Number, default: 1 } }

  pick(event) {
    if (this.checked.length > this.maxValue) this.checked.find((option) => option !== event.target).checked = false
    this.show()
    if (event.target.type === "radio") this.popoverTarget.hidePopover()
  }

  // Checks `max` random options, unchecked ones first.
  random() {
    const shuffle = (options) => options.map((o) => [Math.random(), o]).sort(([a], [b]) => a - b).map(([, o]) => o)
    const picks = [...shuffle(this.optionTargets.filter((o) => !o.checked)), ...shuffle(this.checked)].slice(0, this.maxValue)
    this.optionTargets.forEach((option) => { option.checked = picks.includes(option) })
    this.show()
  }

  show() {
    this.previewTarget.replaceChildren(...this.checked.map((option) => option.nextElementSibling.cloneNode(true)))
  }

  get checked() {
    return this.optionTargets.filter((option) => option.checked)
  }
}
