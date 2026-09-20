import { Controller } from "@hotwired/stimulus"
import Swiper from "swiper"

// Default: centered loop (After). data-swiper-effect="cards" for stacked cards (Before).
export default class extends Controller {
  connect() {
    const cards = this.element.dataset.swiperEffect === "cards"
    this.swiper = new Swiper(this.element, cards
      ? { effect: "cards", grabCursor: true }
      : { loop: true, centeredSlides: true, slidesPerView: 2, spaceBetween: 12, grabCursor: true })
  }

  disconnect() {
    this.swiper?.destroy(true, true)
  }
}
