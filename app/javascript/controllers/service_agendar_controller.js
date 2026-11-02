import { Controller } from "@hotwired/stimulus"

// Confirma o profissional de UM serviço (este `.service-row`) e navega
// sozinho para a etapa seguinte — sem precisar que o cliente clique em
// "Agendar". Porta para o app real o `scheduleAutoAdvance`/
// `#autoAdvanceToast` do protótipo aprovado (`cliente-agendar.html`): um
// toast fixo com barra de progresso, que navega depois de um atraso curto
// e é pausável.
//
// Cada `.service-row` tem a sua própria instância deste controller (ver
// `data-controller="service-agendar"` no partial), então `this.element` já
// é a linha certa — não precisa subir/descer a árvore para achar "o select
// e o link desta linha" como uma instância compartilhada entre linhas
// precisaria.
//
// O contrato de parâmetros não muda: o link de "Agendar" já sai do servidor
// com `service`/`professional` (quando há um padrão)/`unidade_slug` — este
// controller só reescreve `professional` quando o cliente troca no
// seletor, e navega para a MESMA URL que o clique manual sempre navegou.
export default class extends Controller {
  static targets = [ "link" ]

  disconnect() {
    this.clearPending()
    if (this.toastEl) this.toastEl.remove()
  }

  // O <select> (nativo ou via `professional_select_controller#choose`)
  // mudou: reescreve o `href` do "Agendar" com o profissional escolhido e
  // agenda o avanço. Sem profissional escolhido o parâmetro é removido (e
  // não enviado vazio): `?professional=` na URL faz o `new` cair no
  // caminho de "nenhum profissional escolhido" em vez do caminho de
  // "escolha um" — e sem profissional não há o que avançar sozinho para.
  selectProfessional(event) {
    if (!this.hasLinkTarget) return

    const profissional = event.target.value
    const url = new URL(this.linkTarget.href, window.location.origin)

    if (profissional) {
      url.searchParams.set("professional", profissional)
    } else {
      url.searchParams.delete("professional")
    }

    this.linkTarget.href = url.toString()

    if (profissional) this.scheduleAutoAdvance(450)
    else this.clearPending()
  }

  // Tocar na linha "Escolha o profissional" (fora do seletor) aceita quem
  // já está escolhido — o padrão pré-preenchido pelo servidor, ou quem o
  // cliente já tiver trocado no seletor — e avança. Cliques DENTRO do
  // seletor (gatilho/painel) não chegam aqui: os dois já chamam
  // `stopPropagation` em `professional_select_controller.js`, porque abrir
  // o seletor é uma ação diferente de confirmar quem já está ali.
  confirmDefault() {
    if (!this.hasLinkTarget) return

    const url = new URL(this.linkTarget.href, window.location.origin)
    if (!url.searchParams.get("professional")) return

    this.scheduleAutoAdvance(350)
  }

  // O seletor abriu: pausa o avanço pendente até o cliente decidir — abrir
  // para escolher não pode ao mesmo tempo estar navegando por baixo.
  pausePending() {
    this.clearPending()
    if (this.toastEl) this.toastEl.classList.remove("is-visible")
  }

  // O seletor fechou (escolheu alguém — `selectProfessional` já tratou — ou
  // desistiu clicando fora/Escape). Se já havia um profissional confirmado,
  // retoma o avanço: o mesmo `closeAllPickers` do protótipo aprovado, que
  // garante que fechar o seletor sem trocar de ideia não deixa o cliente
  // "preso" na etapa.
  resumePending() {
    if (!this.hasLinkTarget) return

    const url = new URL(this.linkTarget.href, window.location.origin)
    if (!url.searchParams.get("professional")) return

    this.scheduleAutoAdvance(500)
  }

  scheduleAutoAdvance(delayMs) {
    this.clearPending()

    const toast = this.ensureToast()
    const bar = toast.querySelector(".service-row__advance-bar")
    toast.classList.add("is-visible")
    bar.style.transition = "none"
    bar.style.width = "0%"
    // Força o navegador a aplicar `width: 0%` antes de iniciar a transição
    // — sem este reflow forçado, a barra às vezes anima a partir do valor
    // anterior em vez de zero, porque as duas mudanças de estilo caem no
    // mesmo frame.
    void bar.offsetWidth
    bar.style.transition = `width ${delayMs}ms linear`
    bar.style.width = "100%"

    this.pendingTimer = window.setTimeout(() => {
      this.pendingTimer = null
      toast.classList.remove("is-visible")
      this.go()
    }, delayMs)
  }

  clearPending() {
    if (this.pendingTimer) {
      window.clearTimeout(this.pendingTimer)
      this.pendingTimer = null
    }
  }

  // Navega para a etapa seguinte. `Turbo.visit`, quando o Turbo Drive está
  // carregado, mantém a navegação dentro do ciclo de vida que o resto do
  // app já usa (os links deste fluxo são `data-turbo="false"` só porque a
  // troca de etapa é interceptada por `booking_wizard_controller.js`, não
  // porque o app evite Turbo Drive de propósito); `window.location.href` é
  // o mesmo destino por um caminho mais simples quando o Turbo não está
  // disponível — o clique manual que isto substitui também navegava assim,
  // um `<a>` comum.
  go() {
    if (!this.hasLinkTarget) return

    const href = this.linkTarget.href
    if (window.Turbo) window.Turbo.visit(href)
    else window.location.href = href
  }

  // Um toast por linha, criado só quando o primeiro avanço é agendado (não
  // em `connect`, que roda para toda linha mesmo as nunca confirmadas) e
  // anexado a `document.body` — `position: fixed` no CSS, então a posição
  // na árvore do DOM não importa, e um portal evita qualquer
  // `overflow`/`transform` de `.service-row` ancestral cortando ou
  // deslocando o toast fixo.
  ensureToast() {
    if (this.toastEl) return this.toastEl

    const toast = document.createElement("div")
    toast.className = "service-row__advance-toast"
    toast.setAttribute("role", "status")
    toast.innerHTML =
      '<span>Seguindo para data e horário…</span>' +
      '<div class="service-row__advance-bar"></div>'

    document.body.appendChild(toast)
    this.toastEl = toast
    return toast
  }
}
