import { Controller } from "@hotwired/stimulus"

// Multi-select library media for the sticky bar; setMediaType copies the
// selected ids into the bulk media-type form.
export default class extends Controller {
  static targets = ["item", "checkbox", "bar", "count"]

  connect() {
    this.sync()
  }

  changed() {
    this.sync()
  }

  setMediaType(event) {
    const form = event.target.form
    form.querySelectorAll('input[name="ids[]"]').forEach((input) => input.remove())
    this.checkboxTargets.filter((box) => box.checked).forEach((box) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "ids[]"
      input.value = box.value
      form.append(input)
    })
    form.requestSubmit()
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
}
