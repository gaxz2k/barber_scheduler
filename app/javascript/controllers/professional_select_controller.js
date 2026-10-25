import { Controller } from "@hotwired/stimulus"

// Combobox visual sobre o <select> nativo "com quem" de cada linha de
// serviço — reproduz o painel de dropdown da referência SimplesAgenda (ver
// o contexto da tarefa de redesenho, item 8 da especificação): painel
// branco colado abaixo do campo, mesma largura, opções em maiúsculo, opção
// selecionada em azul sólido com marca de check.
//
// Progressive enhancement: sem JS, o <select> nativo continua sozinho no
// DOM e funciona do jeito que sempre funcionou (ver a skill
// `barber-scheduler-js-toolchain` — nada no fluxo público pode depender de
// JS). Com JS, este controller esconde visualmente o select original
// (ele continua "vivo": é ele quem dispara o `change` que o
// `service-agendar` controller escuta para reescrever o link "Agendar") e
// desenha um botão + painel de opções por cima, sincronizados com ele.
export default class extends Controller {
  connect() {
    this.selectEl = this.element.querySelector("select")
    if (!this.selectEl) return

    this.element.classList.add("service-row__select-wrap--js")
    this.buildTrigger()
    this.buildPanel()
    this.syncTrigger()

    this.onDocumentClick = this.onDocumentClick.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    document.addEventListener("click", this.onDocumentClick)
    this.element.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
  }

  buildTrigger() {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "service-row__select-trigger"
    button.setAttribute("aria-haspopup", "listbox")
    button.setAttribute("aria-expanded", "false")
    button.addEventListener("click", (event) => {
      event.stopPropagation()
      this.toggle()
    })

    this.triggerEl = button
    this.element.appendChild(button)
  }

  buildPanel() {
    const panel = document.createElement("ul")
    panel.className = "service-row__select-panel"
    panel.setAttribute("role", "listbox")
    panel.hidden = true

    Array.from(this.selectEl.options).forEach((option) => {
      const item = document.createElement("li")
      item.className = "service-row__select-option"
      item.setAttribute("role", "option")
      item.dataset.value = option.value
      item.textContent = option.textContent
      item.addEventListener("click", (event) => {
        event.stopPropagation()
        this.choose(option.value)
      })
      panel.appendChild(item)
    })

    this.panelEl = panel
    this.element.appendChild(panel)
  }

  toggle() {
    const abrindo = this.panelEl.hidden
    this.panelEl.hidden = !abrindo
    this.triggerEl.setAttribute("aria-expanded", String(abrindo))
  }

  close() {
    this.panelEl.hidden = true
    this.triggerEl.setAttribute("aria-expanded", "false")
  }

  choose(value) {
    this.selectEl.value = value
    // Dispara o mesmo evento que o <select> nativo dispararia — é o que o
    // `service-agendar` controller escuta para reescrever o link "Agendar"
    // desta linha com o profissional escolhido.
    this.selectEl.dispatchEvent(new Event("change", { bubbles: true }))
    this.syncTrigger()
    this.close()
  }

  syncTrigger() {
    const selecionada = this.selectEl.options[this.selectEl.selectedIndex]
    this.triggerEl.textContent = selecionada ? selecionada.textContent : "Nada selecionado"

    this.panelEl.querySelectorAll(".service-row__select-option").forEach((item) => {
      const ativo = item.dataset.value === this.selectEl.value
      item.classList.toggle("service-row__select-option--active", ativo)
      item.setAttribute("aria-selected", String(ativo))
    })
  }

  onDocumentClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close()
  }
}
