import { Controller } from "@hotwired/stimulus"

// One recipe slot: radios live in a popover; the trigger mirrors the checked media.
export default class extends Controller {
  static targets = ["preview", "popover", "radio"]

  pick(event) {
    this.show(event.target)
    this.popoverTarget.hidePopover()
  }

  random() {
    const others = this.radioTargets.filter((radio) => !radio.checked)
    if (others.length === 0) return
    const radio = others[Math.floor(Math.random() * others.length)]
    radio.checked = true
    this.show(radio)
  }

  show(radio) {
    this.previewTarget.replaceChildren(radio.nextElementSibling.cloneNode(true))
  }
}
