import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["viewport", "track", "slide", "status", "imageFallback"]
  // Três segundos. A galeria é uma faixa de ambiente, e sete segundos era
  // tempo suficiente para o cliente achar que a página travou.
  static values = { interval: { type: Number, default: 3000 } }

  connect() {
    this.index = 0
    this.timer = null
    this.resizeObserver = new ResizeObserver(() => this.positionSlides())
    this.resizeObserver.observe(this.viewportTarget)
    this.positionSlides()
    this.show(0)

    // `prefers-reduced-motion` é a forma de parar a rotação para quem não
    // quer movimento. Não há botão de pausa, e não deve haver: a rotação de
    // 3s fica abaixo do limite de 5s do WCAG 2.2.2, e um botão solto no canto
    // da faixa competia com a foto por atenção. Passar o mouse ou o foco
    // sobre a faixa também para — os `data-action` na view cuidam disso.
    if (!this.prefersReducedMotion()) {
      this.start()
    }
  }

  disconnect() {
    this.stop()
    this.resizeObserver?.disconnect()
  }

  // Só as setas do teclado, e não há alvo de botão para elas na view: isto só
  // é alcançado pelo `keydown` na viewport focável.
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

  start() {
    this.stop()
    // A redução de movimento é conferida de novo aqui, e não só no `connect`:
    // passar o mouse sobre a faixa chama `start`, e iniciar a rotação de
    // alguém que pediu menos movimento seria desobedecer a preferência.
    if (this.prefersReducedMotion()) return

    this.timer = window.setInterval(() => this.next(), this.intervalValue)
  }

  stop() {
    if (this.timer) window.clearInterval(this.timer)
    this.timer = null
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
