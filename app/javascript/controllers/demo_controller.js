import { Controller } from "@hotwired/stimulus"
import gsap from "gsap"

const FPS = 30
const STACK = [
  { xPercent: -72, yPercent: -8, rotation: -8, scale: 0.42 },
  { xPercent: -62, yPercent: 4, rotation: 7, scale: 0.42 }
]

export default class extends Controller {
  static targets = [
    "photo", "phone", "chat", "out", "reply",
    "reels", "reelsTrack", "reel", "scrubber", "timeLabel", "playButton"
  ]

  connect() {
    this.userPaused = false
    this.scrubbing = false
    this.#buildTimeline()

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.timeline.progress(1).pause()
      this.#syncScrubber()
      this.#updatePlayButton()
      return
    }

    this.observer = new IntersectionObserver(
      ([entry]) => {
        if (this.userPaused || this.scrubbing) return
        if (entry.isIntersecting) this.timeline.play()
        else this.timeline.pause()
        this.#updatePlayButton()
      },
      { threshold: 0.35 }
    )
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
    this.timeline?.kill()
    this.#pauseReels()
  }

  togglePlay() {
    if (this.timeline.paused()) {
      this.userPaused = false
      this.scrubbing = false
      this.timeline.play()
    } else {
      this.userPaused = true
      this.timeline.pause()
      this.#pauseReels()
    }
    this.#updatePlayButton()
  }

  scrub() {
    this.scrubbing = true
    this.userPaused = true
    this.timeline.pause()
    this.timeline.progress(Number(this.scrubberTarget.value))
    this.#syncVideosToTimeline()
    this.#updatePlayButton()
    this.#updateTimeLabel()
  }

  #buildTimeline() {
    const photos = this.photoTargets
    const outs = this.outTargets
    const [p0, p1] = photos
    const phone = this.phoneTarget
    const reply = this.replyTarget
    const chat = this.chatTarget
    const reels = this.reelsTarget
    const track = this.reelsTrackTarget

    const center = { xPercent: -50, yPercent: -50, rotation: 0, transformOrigin: "50% 50%" }
    gsap.set(photos, { opacity: 0, scale: 1.15, ...center })
    gsap.set(phone, { opacity: 0, x: 24 })
    gsap.set(outs, { opacity: 0, y: 8 })
    gsap.set(reply, { opacity: 0, y: 8 })
    gsap.set(chat, { opacity: 1, zIndex: 10 })
    gsap.set(reels, { opacity: 0, zIndex: 0 })
    gsap.set(track, { yPercent: 0 })

    this.timeline = gsap.timeline({
      repeat: -1,
      paused: true,
      onUpdate: () => {
        if (!this.scrubbing) this.#syncScrubber()
        this.#updateTimeLabel()
      },
      onRepeat: () => this.#pauseReels()
    })

    const tl = this.timeline

    tl.addLabel("scene1")
    tl.fromTo(p0, { opacity: 0, scale: 1.15 }, { opacity: 1, scale: 1.05, duration: 0.25 }, "scene1")
      .to(p0, { ...STACK[0], xPercent: STACK[0].xPercent - 50, yPercent: STACK[0].yPercent - 50, duration: 0.7, ease: "power2.inOut" })
      .fromTo(p1, { opacity: 0, scale: 1.15 }, { opacity: 1, scale: 1.05, duration: 0.25 })
      .to(p1, { ...STACK[1], xPercent: STACK[1].xPercent - 50, yPercent: STACK[1].yPercent - 50, duration: 0.7, ease: "power2.inOut" })

    tl.addLabel("scene2")
    tl.to(phone, { opacity: 1, x: 0, duration: 0.6, ease: "power2.out" }, "scene2")

    tl.addLabel("scene3")
    photos.forEach((photo, i) => {
      const bubble = outs[i]
      const stack = STACK[i]
      // Arc: down-right, then up-right into chat (above phone)
      tl.set(photo, { zIndex: 30 }, i === 0 ? "scene3" : ">-0.05")
        .to(photo, {
          xPercent: stack.xPercent - 50 + 18,
          yPercent: stack.yPercent - 50 + 28,
          scale: stack.scale * 0.85,
          duration: 0.35,
          ease: "power1.in"
        })
        .to(photo, {
          xPercent: 28,
          yPercent: -12,
          scale: 0.18,
          rotation: 0,
          opacity: 0,
          duration: 0.5,
          ease: "power1.out"
        })
        .to(bubble, { opacity: 1, y: 0, duration: 0.25 }, "<0.35")
    })

    tl.addLabel("scene4")
    tl.to(reply, { opacity: 1, y: 0, duration: 0.35, ease: "power2.out" }, "scene4")
      .to({}, { duration: 0.9 })

    tl.addLabel("scene5")
    tl.to(chat, { opacity: 0, duration: 0.35 }, "scene5")
      .to(reels, { opacity: 1, zIndex: 10, duration: 0.35 }, "scene5")
      .set(chat, { zIndex: 0 })
      .call(() => this.#playReel(0))
      .to({}, { duration: 2.2 })
      .to(track, { yPercent: -100, duration: 0.55, ease: "power2.inOut" })
      .call(() => this.#playReel(1))
      .to({}, { duration: 2.2 })
  }

  #syncScrubber() {
    if (!this.hasScrubberTarget) return
    this.scrubberTarget.value = String(this.timeline.progress())
  }

  #updateTimeLabel() {
    if (!this.hasTimeLabelTarget) return
    const t = this.timeline.time()
    const total = this.timeline.duration()
    const frame = Math.round(t * FPS)
    const frames = Math.round(total * FPS)
    this.timeLabelTarget.textContent = `${frame} / ${frames} · ${t.toFixed(2)}s`
  }

  #updatePlayButton() {
    if (!this.hasPlayButtonTarget) return
    this.playButtonTarget.textContent = this.timeline.paused() ? "Play" : "Pause"
  }

  #playReel(index) {
    this.#pauseReels()
    const el = this.reelTargets[index]
    if (!el || this.timeline.paused()) return
    el.currentTime = 0
    el.play?.().catch(() => {})
  }

  #pauseReels() {
    this.reelTargets.forEach((el) => {
      el.pause?.()
    })
  }

  #syncVideosToTimeline() {
    this.#pauseReels()
    const labels = this.timeline.labels
    const t = this.timeline.time()
    const scene5 = labels.scene5 ?? 0
    if (t < scene5) {
      this.reelTargets.forEach((el) => { try { el.currentTime = 0 } catch (_) { /* noop */ } })
      return
    }
    // Approximate which reel based on track position
    const y = gsap.getProperty(this.reelsTrackTarget, "yPercent")
    const idx = y < -50 ? 1 : 0
    const el = this.reelTargets[idx]
    if (el) try { el.currentTime = 0 } catch (_) { /* noop */ }
  }
}
