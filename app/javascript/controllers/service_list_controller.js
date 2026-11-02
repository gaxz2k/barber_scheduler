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

  selectRow(event) {
    const row = event.target.closest(".service-row")
    if (!row || !this.rowTargets.includes(row)) return

    this.rowTargets.forEach((candidate) => {
      candidate.classList.toggle("is-selected", candidate === row)
    })
  }
}
