import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["viewport", "track", "slide", "status", "imageFallback", "pause"]
  static values = { interval: { type: Number, default: 6500 } }

  connect() {
    this.index = 0
    this.timer = null
    this.userPaused = this.prefersReducedMotion()
    this.resizeObserver = new ResizeObserver(() => this.positionSlides())
    this.resizeObserver.observe(this.viewportTarget)
    this.positionSlides()
    this.show(0)
    this.updatePauseButton()

    if (!this.prefersReducedMotion()) {
      this.start()
    }
  }

  disconnect() {
    this.stop()
    this.resizeObserver?.disconnect()
  }

  previous = () => this.show(this.index - 1)
  next = () => this.show(this.index + 1)

  show(index) {
    const total = this.slideTargets.length
    if (total === 0) return

    this.index = (index + total) % total
    this.positionSlides()
    this.slideTargets.forEach((slide, slideIndex) => {
      slide.setAttribute("aria-hidden", slideIndex === this.index ? "false" : "true")
    })
    this.statusTarget.textContent = `Foto ${this.index + 1} de ${total}`
  }

  start(force = false) {
    this.stop()
    if (this.userPaused || (!force && this.prefersReducedMotion())) return

    this.timer = window.setInterval(() => this.next(), this.intervalValue)
  }

  stop() {
    if (this.timer) window.clearInterval(this.timer)
    this.timer = null
  }

  togglePause() {
    this.userPaused = !this.userPaused
    this.updatePauseButton()
    if (this.userPaused) {
      this.stop()
      this.statusTarget.textContent = "Carrossel pausado."
    } else {
      this.start(true)
      this.statusTarget.textContent = `Foto ${this.index + 1} de ${this.slideTargets.length}`
    }
  }

  updatePauseButton() {
    if (!this.hasPauseTarget) return

    this.pauseTarget.setAttribute("aria-pressed", this.userPaused.toString())
    this.pauseTarget.setAttribute("aria-label", this.userPaused ? "Retomar carrossel" : "Pausar carrossel")
    this.pauseTarget.textContent = this.userPaused ? "▶" : "Ⅱ"
  }

  prefersReducedMotion() {
    return window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false
  }

  positionSlides() {
    const width = this.viewportTarget.clientWidth
    this.trackTarget.style.transform = `translate3d(-${this.index * width}px, 0, 0)`
    this.slideTargets.forEach((slide) => {
      slide.style.width = `${width}px`
    })
  }

  keydown(event) {
    if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.previous()
    }
    if (event.key === "ArrowRight") {
      event.preventDefault()
      this.next()
    }
  }

  imageError(event) {
    const image = event.currentTarget
    const fallback = image.closest(".barbershop-carousel__image-wrap")?.querySelector(
      "[data-barbershop-carousel-target='imageFallback']"
    )
    if (!fallback) return

    image.hidden = true
    fallback.hidden = false
    this.statusTarget.textContent = "Uma das fotos não pôde ser carregada."
  }
}
