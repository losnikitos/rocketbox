import { Controller } from "@hotwired/stimulus"

// Hidden multipart form: drop files anywhere on the nearest <main> to upload.
export default class extends Controller {
  static targets = ["input"]

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
  }

  dragover(event) {
    event.preventDefault()
    this.zone.dataset.dragging = ""
  }

  dragleave(event) {
    if (this.zone.contains(event.relatedTarget)) return
    delete this.zone.dataset.dragging
  }

  drop(event) {
    event.preventDefault()
    delete this.zone.dataset.dragging
    this.assignFiles(event.dataTransfer.files)
  }

  changed() {
    if (this.inputTarget.files.length) this.element.requestSubmit()
  }

  assignFiles(fileList) {
    const dt = new DataTransfer()
    Array.from(fileList).forEach((file) => {
      if (file.type.startsWith("image/") || file.type.startsWith("video/")) dt.items.add(file)
    })
    if (!dt.files.length) return

    this.inputTarget.files = dt.files
    this.element.requestSubmit()
  }
}
