import { Controller } from "@hotwired/stimulus"

// Debounced form autosave. Success: green check in the field. Failure: toast.
export default class extends Controller {
  static targets = ["indicator"]
  static values = { delay: { type: Number, default: 400 } }

  connect() {
    this.timer = null
    this.hideTimer = null
    this.abort = null
  }

  disconnect() {
    clearTimeout(this.timer)
    clearTimeout(this.hideTimer)
    this.abort?.abort()
  }

  queue(event) {
    const field = event.target
    if (!field.matches("input, textarea, select")) return
    if (!field.name || field.type === "submit") return

    this.activeField = field
    clearTimeout(this.timer)
    const delay = field.type === "file" ? 0 : this.delayValue
    this.timer = setTimeout(() => this.save(), delay)
  }

  submit(event) {
    event.preventDefault()
    clearTimeout(this.timer)
    this.save()
  }

  async save() {
    const form = this.element
    if (!form.reportValidity()) return

    const field = this.activeField
    this.abort?.abort()
    this.abort = new AbortController()

    try {
      const response = await fetch(form.action, {
        method: form.getAttribute("method") || "post",
        body: new FormData(form),
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
          "X-Autosave": "1"
        },
        credentials: "same-origin",
        signal: this.abort.signal
      })

      if (!response.ok) {
        let message = "Couldn't save. Try again."
        try {
          const json = await response.json()
          if (json.error) message = json.error
        } catch {
          // keep default
        }
        this.toast(message)
        return
      }

      this.showOk(field)
      if (field?.type === "file") window.location.reload()
    } catch (error) {
      if (error.name === "AbortError") return
      this.toast("Couldn't save. Try again.")
    }
  }

  showOk(field) {
    if (!field) return
    const wrap = field.closest("[data-autosave-field]")
    const indicator = wrap?.querySelector("[data-autosave-target='indicator']")
    if (!indicator) return

    this.indicatorTargets.forEach((el) => el.removeAttribute("data-saved"))
    indicator.setAttribute("data-saved", "")
    clearTimeout(this.hideTimer)
    this.hideTimer = setTimeout(() => indicator.removeAttribute("data-saved"), 2000)
  }

  toast(message) {
    const host = document.querySelector("[data-toast-host]")
    const template = document.querySelector("#toast-alert-template")
    if (!host || !template) return

    const node = template.content.firstElementChild.cloneNode(true)
    node.querySelector("[data-toast-message]").textContent = message
    host.appendChild(node)
  }
}
