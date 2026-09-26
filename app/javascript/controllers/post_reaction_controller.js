import { Controller } from "@hotwired/stimulus"

// Instant thumbs up/down on a generated post. Comment only for thumbs down.
export default class extends Controller {
  static targets = ["up", "down", "comment", "commentField"]
  static values = {
    url: String,
    reaction: { type: String, default: "" }
  }

  connect() {
    this.sync()
  }

  up() {
    this.persist(this.reactionValue === "up" ? "" : "up")
  }

  down() {
    this.persist(this.reactionValue === "down" ? "" : "down")
  }

  async submitComment(event) {
    event.preventDefault()
    if (this.reactionValue !== "down") return
    await this.persist("down", this.commentFieldTarget.value)
  }

  async persist(reaction, comment) {
    this.reactionValue = reaction
    if (reaction !== "down" && this.hasCommentFieldTarget) {
      this.commentFieldTarget.value = ""
    }
    this.sync()

    const body = new FormData()
    body.append("reaction", reaction)
    if (reaction === "down" && comment !== undefined) {
      body.append("reaction_comment", comment)
    }

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        body,
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error("save failed")
    } catch {
      // Keep optimistic UI; customer can click again.
    }
  }

  sync() {
    const reaction = this.reactionValue
    this.upTarget.setAttribute("aria-pressed", reaction === "up" ? "true" : "false")
    this.downTarget.setAttribute("aria-pressed", reaction === "down" ? "true" : "false")
    this.commentTarget.hidden = reaction !== "down"
  }
}
