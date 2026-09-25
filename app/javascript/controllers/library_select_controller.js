import { Controller } from "@hotwired/stimulus"

// Multi-select library media. Checkboxes use form="create-instagram-post"
// so selected ids submit with the sticky-bar GET form.
export default class extends Controller {
  static targets = ["item", "checkbox", "bar", "count"]
  static values = { max: { type: Number, default: 7 } }

  connect() {
    this.sync()
  }

  selectItem(event) {
    if (event.target.closest("a, button, form, input, label, video")) return

    const box = event.currentTarget.querySelector('input[type="checkbox"][data-library-select-target="checkbox"]')
    if (!box) return

    box.checked = !box.checked
    this.enforceMax(box)
    this.sync()
  }

  changed(event) {
    this.enforceMax(event.target)
    this.sync()
  }

  selectAllImages(event) {
    event.preventDefault()
    this.imageCheckboxes().forEach((box, index) => {
      box.checked = index < this.maxValue
    })
    this.sync()
  }

  clear(event) {
    event.preventDefault()
    this.checkboxTargets.forEach((box) => { box.checked = false })
    this.sync()
  }

  enforceMax(preferred) {
    const selected = this.checkboxTargets.filter((box) => box.checked)
    if (selected.length <= this.maxValue) return

    const overflow = selected.length - this.maxValue
    const candidates = preferred?.checked ? selected.filter((box) => box !== preferred) : selected
    candidates.slice(0, overflow).forEach((box) => { box.checked = false })
  }

  sync() {
    const ids = this.checkboxTargets.filter((box) => box.checked).map((box) => box.value)

    if (this.hasCountTarget) {
      this.countTarget.textContent = String(ids.length)
    }

    if (this.hasBarTarget) {
      const open = ids.length > 0
      this.barTarget.classList.toggle("hidden", !open)
      this.barTarget.classList.toggle("flex", open)
      this.barTarget.toggleAttribute("data-open", open)
    }

    this.itemTargets.forEach((item) => {
      const box = item.querySelector('input[type="checkbox"][data-library-select-target="checkbox"]')
      const on = Boolean(box?.checked)
      item.classList.toggle("ring-2", on)
      item.classList.toggle("ring-rocket", on)
    })
  }

  imageCheckboxes() {
    return this.checkboxTargets.filter((box) => box.dataset.image === "true")
  }
}
