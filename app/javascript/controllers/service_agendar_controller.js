import { Controller } from "@hotwired/stimulus"

// Mantém o link "Agendar" de um serviço (`.service-row__go`) sincronizado
// com o profissional escolhido no seletor — a única responsabilidade deste
// controller depois do pedido de Nicholas ("em vez de selecionar o
// barbeiro e ir pro próximo, coloca um botão Agendar"): escolher o
// profissional não navega mais sozinho (era `scheduleAutoAdvance`, com um
// toast fixo e barra de progresso — removidos inteiros, junto com
// `confirmDefault`/`pausePending`/`resumePending`, que só existiam pra
// coordenar aquele avanço automático com o seletor abrindo/fechando). O
// clique no "Agendar" agora é um `<a>` comum: navega sozinho, sem
// intervenção de JS nenhuma, pela mesma máquina de interceptação de
// `booking_wizard_controller.js` que todo link de etapa já usa
// (`data-turbo="false"` + `data-step-link`).
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

  // O <select> (nativo ou via `professional_select_controller#choose`)
  // mudou: reescreve o `href` do "Agendar" com o profissional escolhido.
  // Sem profissional escolhido o parâmetro é removido (e não enviado
  // vazio): `?professional=` na URL faz o `new` cair no caminho de
  // "nenhum profissional escolhido" em vez do caminho de "escolha um".
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
  }
}
