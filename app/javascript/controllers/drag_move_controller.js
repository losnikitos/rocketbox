import { Controller } from "@hotwired/stimulus"

// Drag a [data-move-url] tile onto a [data-folder-id] tree entry to move it there.
export default class extends Controller {
  static targets = ["form", "folder"]

  start(event) {
    this.url = event.target.closest("[data-move-url]")?.dataset.moveUrl
    if (this.url) event.dataTransfer.effectAllowed = "move"
  }

  over(event) {
    const folder = this.url && event.target.closest("[data-folder-id]")
    this.highlight(folder)
    if (!folder) return
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  leave(event) {
    if (!this.target?.contains(event.relatedTarget)) this.highlight(null)
  }

  drop(event) {
    const folder = this.url && event.target.closest("[data-folder-id]")
    if (!folder) return
    event.preventDefault()
    this.formTarget.action = this.url
    this.folderTarget.value = folder.dataset.folderId
    this.formTarget.requestSubmit()
    this.end()
  }

  end() {
    this.url = null
    this.highlight(null)
  }

  highlight(folder) {
    if (this.target === folder) return
    if (this.target) delete this.target.dataset.dropOver
    this.target = folder
    if (folder) folder.dataset.dropOver = ""
  }
}
