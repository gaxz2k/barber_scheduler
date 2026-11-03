import { Controller } from "@hotwired/stimulus"

// Dono da lista inteira de serviços: sabe qual linha está "aberta" agora
// (comportamento de rádio — só uma por vez, como no protótipo aprovado
// `cliente-agendar.html`) e marca `.service-list--js` no elemento assim que
// conecta.
//
// Essa marca é o que liga TODA a versão "com JS" deste componente — ver os
// seletores `.service-list--js ...` em `booking_wizard.css`. Sem ela (JS
// desligado, ou antes deste controller conectar), a seção "Escolha o
// profissional" de cada linha já está sempre visível e o botão "Agendar"
// sempre clicável: a mesma degradação graciosa do resto do fluxo público
// (ver a skill `barber-scheduler-js-toolchain`).
//
// Esta responsabilidade (qual serviço está aberto) é separada de
// `service_agendar_controller.js` (confirmar o profissional daquele
// serviço e navegar) de propósito: um controller por `.service-row` não
// tem como saber dos OUTROS `.service-row` da mesma lista sem subir até um
// ancestral comum — e esse ancestral é este controller.
export default class extends Controller {
  static targets = [ "row" ]

  connect() {
    this.element.classList.add("service-list--js")
  }

  // BUG achado por Nicholas ("ao selecionar últimos agendamentos ele
  // bugs" / "ainda ficou grande"): a home tem DUAS `<section
  // class="service-list">` na mesma página — "Últimos Agendamentos" e
  // "Escolha um serviço" — cada uma com a sua PRÓPRIA instância deste
  // controller (ver `appointments/_service_rows`, chamado duas vezes com
  // `scope` diferente). `this.rowTargets` só enxerga as linhas da MESMA
  // instância/seção, então abrir um card em "Últimos Agendamentos" e
  // depois outro em "Escolha um serviço" deixava os DOIS abertos ao mesmo
  // tempo — daí a tela "ficando grande", mesmo serviço reaparecendo
  // selecionado duas vezes.
  //
  // `document.querySelectorAll` (não `this.rowTargets`) resolve isso
  // fechando TODO `.service-row` da PÁGINA, não só desta seção — o
  // comportamento de rádio passa a valer pro conjunto das duas listas
  // juntas, que é como o cliente enxerga a tela (um serviço só sendo
  // escolhido por vez, não um por seção).
  selectRow(event) {
    const row = event.target.closest(".service-row")
    if (!row) return

    document.querySelectorAll(".service-row.is-selected").forEach((candidate) => {
      if (candidate !== row) candidate.classList.remove("is-selected")
    })
    row.classList.add("is-selected")
  }
}
