import { Controller } from "@hotwired/stimulus"

// Drag a [data-move-url] tile onto a [data-move-to] target to PATCH that value into the form's value field.
// A target with [data-move-prompt] asks for the value instead.
export default class extends Controller {
  static targets = ["form", "value"]

  start(event) {
    this.url = event.target.closest("[data-move-url]")?.dataset.moveUrl
    if (this.url) event.dataTransfer.effectAllowed = "move"
  }

  over(event) {
    const target = this.url && event.target.closest("[data-move-to]")
    this.highlight(target)
    if (!target) return
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  leave(event) {
    if (!this.target?.contains(event.relatedTarget)) this.highlight(null)
  }

  drop(event) {
    const target = this.url && event.target.closest("[data-move-to]")
    if (!target) return
    event.preventDefault()
    const { moveTo, movePrompt } = target.dataset
    const value = movePrompt ? prompt(movePrompt)?.trim() : moveTo
    if (!movePrompt || value) {
      this.formTarget.action = this.url
      this.valueTarget.value = value
      this.formTarget.requestSubmit()
    }
    this.end()
  }

  end() {
    this.url = null
    this.highlight(null)
  }

  highlight(target) {
    if (this.target === target) return
    if (this.target) delete this.target.dataset.dropOver
    this.target = target
    if (target) target.dataset.dropOver = ""
  }
}
