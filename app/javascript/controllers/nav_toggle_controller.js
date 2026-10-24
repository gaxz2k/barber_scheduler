import { Controller } from "@hotwired/stimulus"

// Abre/fecha o menu da nav do admin em telas estreitas (ver a regra
// `@media (max-width: 760px)` em design_components.css). O menu some de
// Turbo em toda navegação porque o controller reconecta do zero a cada
// troca de página — não precisa de lógica extra para "fechar ao navegar".
export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    const isOpen = this.menuTarget.classList.toggle("nav__links--open")
    this.element.setAttribute("aria-expanded", isOpen)
  }
}
