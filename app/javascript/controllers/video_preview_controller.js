import { Controller } from "@hotwired/stimulus"

// Click-to-play preview for muted looping videos (e.g. posts index thumbs).
export default class extends Controller {
  static targets = ["video", "button"]

  toggle() {
    const video = this.videoTarget
    if (video.paused) {
      video.play().catch(() => {})
      this.element.toggleAttribute("data-playing", true)
      if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-label", "Pause video")
    } else {
      video.pause()
      this.element.toggleAttribute("data-playing", false)
      if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-label", "Play video")
    }
  }
}
