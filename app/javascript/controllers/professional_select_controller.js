import { Controller } from "@hotwired/stimulus"

// Combobox visual sobre o <select> nativo "com quem" de cada linha de
// serviço — reproduz o seletor compacto do protótipo aprovado
// (`.pro-picker-trigger` em `cliente-agendar.html`): gatilho pequeno e
// "quadrado" (foto/inicial + primeiro nome + seta, `border-radius`
// var(--dt-radius-md), não pílula) que abre um painel com foto/inicial +
// nome completo de cada profissional.
//
// Progressive enhancement: sem JS, o <select> nativo continua sozinho no
// DOM e funciona do jeito que sempre funcionou (ver a skill
// `barber-scheduler-js-toolchain` — nada no fluxo público pode depender de
// JS). Com JS, este controller esconde visualmente o select original
// (ele continua "vivo": é ele quem dispara o `change` que o
// `service-agendar` controller escuta para reescrever o link "Agendar" e
// agendar o avanço automático) e desenha um botão + painel de opções por
// cima, sincronizados com ele.
//
// O avatar (foto ou inicial) vem de `data-photo-url`/`data-initial` nas
// próprias `<option>` — os mesmos atributos que o partial já renderiza para
// cada profissional (ver `appointments/_service_rows`). Ler dali, e não
// buscar os profissionais de novo via `fetch`, é o que evita uma segunda
// fonte de dados (e uma segunda chance de divergir) só para desenhar um
// círculo com uma foto.
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

    this.avatarSlotEl = document.createElement("span")
    this.avatarSlotEl.className = "service-row__select-avatar"

    this.nameEl = document.createElement("span")
    this.nameEl.className = "service-row__select-trigger-name"

    // A mesma seta ("chevron-down") de `IconHelper`, replicada aqui em vez
    // de vir do Ruby: este trecho de SVG é construído em runtime pelo JS,
    // e `icon_tag` só existe do lado do servidor. O desenho (viewBox,
    // stroke) é copiado de propósito para não ficar um segundo ícone com
    // traço diferente do resto do produto.
    button.insertAdjacentHTML(
      "beforeend",
      '<svg class="service-row__select-trigger-chevron" viewBox="0 0 24 24" width="24" height="24" ' +
      'fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
      '<path d="M5 8.5 12 15.5 19 8.5"/></svg>'
    )
    this.chevronEl = button.querySelector(".service-row__select-trigger-chevron")

    button.prepend(this.nameEl)
    button.prepend(this.avatarSlotEl)

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

      const avatar = this.buildAvatar(option)
      if (avatar) item.appendChild(avatar)

      const label = document.createElement("span")
      label.className = "service-row__select-option-label"
      label.textContent = option.textContent
      item.appendChild(label)

      item.addEventListener("click", (event) => {
        event.stopPropagation()
        this.choose(option.value)
      })
      panel.appendChild(item)
    })

    this.panelEl = panel
    this.element.appendChild(panel)
  }

  // Um avatar por opção: foto do profissional quando cadastrada
  // (`data-photo-url`), inicial do nome quando não (`data-initial`) — nunca
  // para a opção vazia ("Nada selecionado"), que não representa uma
  // pessoa e não tem nenhum dos dois atributos.
  buildAvatar(option) {
    if (!option.value) return null

    const photoUrl = option.dataset.photoUrl
    if (photoUrl) {
      const img = document.createElement("img")
      img.className = "service-row__select-avatar-img"
      img.src = photoUrl
      img.alt = ""
      img.loading = "lazy"
      return img
    }

    const initial = document.createElement("span")
    initial.className = "service-row__select-avatar-initial"
    initial.textContent = option.dataset.initial || ""
    return initial
  }

  toggle() {
    const abrindo = this.panelEl.hidden
    this.panelEl.hidden = !abrindo
    this.triggerEl.setAttribute("aria-expanded", String(abrindo))
    // O `service-agendar` da linha escuta este evento (bubbling até
    // `.service-row`) para pausar o avanço automático pendente enquanto o
    // cliente está decidindo quem escolher — ver
    // `service_agendar_controller.js#pausePending`.
    this.element.dispatchEvent(
      new CustomEvent(abrindo ? "professional-select:open" : "professional-select:close", { bubbles: true })
    )
  }

  close() {
    if (this.panelEl.hidden) return

    this.panelEl.hidden = true
    this.triggerEl.setAttribute("aria-expanded", "false")
    // Fechar sem escolher ninguém (clique fora, Escape) retoma o avanço
    // pendente com quem já estava selecionado — é o `resumePending` do
    // `service-agendar`, o mesmo comportamento de `closeAllPickers` do
    // protótipo aprovado.
    this.element.dispatchEvent(new CustomEvent("professional-select:close", { bubbles: true }))
  }

  choose(value) {
    const trocou = value !== this.selectEl.value
    this.selectEl.value = value
    // Dispara o mesmo evento que o <select> nativo dispararia — é o que o
    // `service-agendar` controller escuta para reescrever o link "Agendar"
    // desta linha com o profissional escolhido e agendar o avanço
    // automático.
    this.selectEl.dispatchEvent(new Event("change", { bubbles: true }))
    this.syncTrigger({ pop: trocou })
    this.close()
  }

  // `pop` só é `true` quando `choose()` troca de fato o profissional — a
  // sincronização inicial (`connect`) e um re-`choose` da MESMA pessoa não
  // disparam a animação, que existe para confirmar visualmente uma
  // mudança, não para decorar toda renderização.
  syncTrigger({ pop = false } = {}) {
    const selecionada = this.selectEl.options[this.selectEl.selectedIndex]

    this.avatarSlotEl.replaceChildren()
    const avatar = selecionada ? this.buildAvatar(selecionada) : null
    if (avatar) {
      if (pop) avatar.classList.add("is-popping")
      this.avatarSlotEl.appendChild(avatar)
    }

    // "Sem preferência"/nomes compostos mostram só o primeiro nome no
    // gatilho compacto — é o mesmo corte do protótipo aprovado
    // (`pro-picker-name`), que existe porque o gatilho tem largura fixa
    // pequena de propósito (ver `.service-row__select-trigger` no CSS): o
    // nome completo de "Rafael Souza" estouraria essa largura, e o nome
    // completo continua visível no painel de opções logo abaixo.
    this.nameEl.textContent = selecionada && selecionada.value
      ? selecionada.textContent.trim().split(" ")[0]
      : "Escolher"

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
