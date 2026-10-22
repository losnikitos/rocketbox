import { Controller } from "@hotwired/stimulus"

// Chosen files live on their <li> and are mirrored into the file input, so removing one drops it from the submit.
export default class extends Controller {
  static targets = ["input", "previews"]

  disconnect() {
    this.previewsTarget.querySelectorAll("li").forEach((li) => li.url && URL.revokeObjectURL(li.url))
  }

  pick() {
    this.add(this.inputTarget.files)
  }

  over(event) {
    if (!event.dataTransfer?.types.includes("Files")) return
    event.preventDefault()
    this.element.dataset.dragging = ""
  }

  leave(event) {
    if (this.element.contains(event.relatedTarget)) return
    delete this.element.dataset.dragging
  }

  drop(event) {
    if (!event.dataTransfer?.types.includes("Files")) return
    event.preventDefault()
    delete this.element.dataset.dragging
    this.add(event.dataTransfer.files)
  }

  add(files) {
    this.previewsTarget.append(...Array.from(files, (file) => this.chip(file)))
    this.sync()
  }

  remove(event) {
    const li = event.currentTarget.closest("li")
    if (li.url) URL.revokeObjectURL(li.url)
    li.remove()
    this.sync()
  }

  keydown(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return
    event.preventDefault()
    this.element.requestSubmit()
  }

  // turbo:submit-start fires after FormData is built, so the request still has the text and files.
  clear() {
    const body = this.element.querySelector("textarea")
    if (body) body.value = ""
    this.previewsTarget.querySelectorAll("li").forEach((li) => {
      if (li.url) URL.revokeObjectURL(li.url)
      li.remove()
    })
    this.sync()
  }

  sync() {
    const transfer = new DataTransfer()
    this.previewsTarget.querySelectorAll("li").forEach((li) => li.file && transfer.items.add(li.file))
    this.inputTarget.files = transfer.files
  }

  chip(file) {
    const li = document.createElement("li")
    li.className = "relative shrink-0"
    li.file = file
    if (file.type.startsWith("image/")) {
      li.url = URL.createObjectURL(file)
      li.append(Object.assign(document.createElement("img"), { src: li.url, alt: "", className: "size-16 rounded-lg object-cover" }))
    } else if (file.type.startsWith("video/")) {
      li.url = URL.createObjectURL(file)
      li.append(Object.assign(document.createElement("video"), {
        src: li.url, muted: true, playsInline: true, preload: "metadata", className: "size-16 rounded-lg bg-ink-900/5 object-cover"
      }))
    } else {
      const name = document.createElement("span")
      name.className = "flex h-16 max-w-40 items-center rounded-lg bg-white px-2 text-xs break-all text-ink-700"
      name.textContent = file.name
      li.append(name)
    }

    const remove = document.createElement("button")
    remove.type = "button"
    remove.className = "absolute -top-1 -right-1 flex size-5 cursor-pointer items-center justify-center rounded-full bg-ink-900 text-xs leading-none text-white"
    remove.setAttribute("aria-label", `Remove ${file.name}`)
    remove.setAttribute("data-action", "whatsapp-composer#remove")
    remove.textContent = "×"
    li.append(remove)
    return li
  }
}
