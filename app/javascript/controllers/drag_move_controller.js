import { Controller } from "@hotwired/stimulus"

// Drag a [data-move-url] tile onto a [data-move-to] target to PATCH that value into the form's value field.
// A tile can drop onto another attribute ([data-move-attr]) into another field ([data-move-field]),
// skipping the target holding the value it already has ([data-move-from]).
// A target with [data-move-prompt] asks for the value instead.
export default class extends Controller {
  static targets = ["form", "value"]

  start(event) {
    const source = event.target.closest("[data-move-url]")
    if (!source) return
    const { moveUrl: url, moveAttr: attr = "data-move-to", moveField: field = "library_media[folder_id]", moveFrom: from } = source.dataset
    this.move = { url, attr, field, from }
    event.dataTransfer.effectAllowed = "move"
  }

  over(event) {
    const target = this.targetFor(event)
    this.highlight(target)
    if (!target) return
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  leave(event) {
    if (!this.target?.contains(event.relatedTarget)) this.highlight(null)
  }

  drop(event) {
    const target = this.targetFor(event)
    if (!target) return
    event.preventDefault()
    const { movePrompt } = target.dataset
    const value = movePrompt ? prompt(movePrompt)?.trim() : target.getAttribute(this.move.attr)
    if (!movePrompt || value) {
      this.formTarget.action = this.move.url
      this.valueTarget.name = this.move.field
      this.valueTarget.value = value
      this.formTarget.requestSubmit()
    }
    this.end()
  }

  end() {
    this.move = null
    this.highlight(null)
  }

  targetFor(event) {
    const target = this.move && event.target.closest(`[${this.move.attr}]`)
    return target && target.getAttribute(this.move.attr) !== this.move.from ? target : null
  }

  highlight(target) {
    if (this.target === target) return
    if (this.target) delete this.target.dataset.dropOver
    this.target = target
    if (target) target.dataset.dropOver = ""
  }
}
