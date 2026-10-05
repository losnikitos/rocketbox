import { Controller } from "@hotwired/stimulus"

// Hidden multipart form: drop files anywhere on the nearest <main> to upload.
// Dropping onto a [data-source-id] group attaches the files to that source.
export default class extends Controller {
  static targets = ["input", "source"]

  connect() {
    this.zone = this.element.closest("main") || this.element
    this.onDragover = this.dragover.bind(this)
    this.onDragleave = this.dragleave.bind(this)
    this.onDrop = this.drop.bind(this)
    this.zone.addEventListener("dragover", this.onDragover)
    this.zone.addEventListener("dragleave", this.onDragleave)
    this.zone.addEventListener("drop", this.onDrop)
  }

  disconnect() {
    this.zone.removeEventListener("dragover", this.onDragover)
    this.zone.removeEventListener("dragleave", this.onDragleave)
    this.zone.removeEventListener("drop", this.onDrop)
    delete this.zone.dataset.dragging
    this.highlight(null)
  }

  dragover(event) {
    if (!event.dataTransfer.types.includes("Files")) return
    event.preventDefault()
    this.zone.dataset.dragging = ""
    this.highlight(event.target.closest("[data-source-id]"))
  }

  dragleave(event) {
    if (this.zone.contains(event.relatedTarget)) return
    delete this.zone.dataset.dragging
    this.highlight(null)
  }

  drop(event) {
    if (!event.dataTransfer.types.includes("Files")) return
    event.preventDefault()
    delete this.zone.dataset.dragging
    this.highlight(null)
    this.sourceTarget.value = event.target.closest("[data-source-id]")?.dataset.sourceId || ""
    this.assignFiles(event.dataTransfer.files)
  }

  highlight(group) {
    if (this.group === group) return
    if (this.group) delete this.group.dataset.dropOver
    this.group = group
    if (group) group.dataset.dropOver = ""
  }

  changed() {
    this.sourceTarget.value = ""
    if (this.inputTarget.files.length) this.element.requestSubmit()
  }

  assignFiles(fileList) {
    const dt = new DataTransfer()
    Array.from(fileList).forEach((file) => {
      if (/^(image|video)\//.test(file.type) || /\.hei[cf]$/i.test(file.name)) dt.items.add(file)
    })
    if (!dt.files.length) return

    this.inputTarget.files = dt.files
    this.element.requestSubmit()
  }
}
