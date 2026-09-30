import { Controller } from "@hotwired/stimulus"

// Saved and picked examples share one list; removing either only takes effect on save.
// The whole panel is a drop target; the "+" tile (add target) stays last and holds the picker input.
// Picked files live on their <li> (li.file) and are mirrored into the file input.
export default class extends Controller {
  static targets = ["input", "list", "add", "remove"]

  disconnect() {
    this.listTarget.querySelectorAll("li").forEach((li) => li.url && URL.revokeObjectURL(li.url))
  }

  show() {
    this.add(this.inputTarget.files)
  }

  over(event) {
    if (!event.dataTransfer.types.includes("Files")) return
    event.preventDefault()
    this.element.dataset.dragging = ""
  }

  leave(event) {
    if (!this.element.contains(event.relatedTarget)) delete this.element.dataset.dragging
  }

  drop(event) {
    if (!event.dataTransfer.types.includes("Files")) return
    event.preventDefault()
    delete this.element.dataset.dragging
    this.add(Array.from(event.dataTransfer.files).filter((file) => /^(image|video)\//.test(file.type)))
  }

  add(files) {
    this.addTarget.before(...Array.from(files, (file) => this.thumb(file)))
    this.sync()
  }

  remove(event) {
    const li = event.currentTarget.closest("li")
    if (li.url) URL.revokeObjectURL(li.url)
    li.remove()
    this.sync()
  }

  sync() {
    const transfer = new DataTransfer()
    this.listTarget.querySelectorAll("li").forEach((li) => li.file && transfer.items.add(li.file))
    this.inputTarget.files = transfer.files
  }

  thumb(file) {
    const li = document.createElement("li")
    li.className = "group relative"
    li.file = file
    li.url = URL.createObjectURL(file)

    const css = "aspect-2/3 w-full rounded-lg object-cover"
    if (file.type.startsWith("video/")) {
      li.append(Object.assign(document.createElement("video"), {
        src: li.url, muted: true, playsInline: true, preload: "metadata", className: `bg-ink-900/5 ${css}`
      }))
    } else {
      const id = `example-${crypto.randomUUID()}`
      const open = Object.assign(document.createElement("button"), { type: "button", className: "block w-full cursor-zoom-in" })
      open.setAttribute("popovertarget", id)
      open.setAttribute("aria-label", `View ${file.name}`)
      open.append(Object.assign(document.createElement("img"), { src: li.url, alt: file.name, className: css }))

      const popover = Object.assign(document.createElement("div"), { id, popover: "auto", className: "size-full bg-black/90 p-4" })
      const close = Object.assign(document.createElement("button"), {
        type: "button", className: "flex size-full cursor-zoom-out items-center justify-center"
      })
      close.setAttribute("popovertarget", id)
      close.setAttribute("popovertargetaction", "hide")
      close.setAttribute("aria-label", "Close")
      close.append(Object.assign(document.createElement("img"), { src: li.url, alt: file.name, className: "max-h-full max-w-full" }))
      popover.append(close)
      li.append(open, popover)
    }

    const remove = this.removeTarget.content.firstElementChild.cloneNode(true)
    remove.setAttribute("aria-label", `Remove ${file.name}`)
    li.append(remove)
    return li
  }
}
