import { Controller } from "@hotwired/stimulus"

// Um card único, três etapas internas — arquitetura da referência
// SimplesAgenda (ver o comentário no topo de `new.html.erb`).
//
// Este controller faz três coisas, e só três:
//
//   1. Troca de etapa sem navegar: qualquer link ou formulário GET dentro do
//      cartão marcado com `data-step-link` é interceptado, buscado via
//      `fetch`, e o `.booking-flow` da resposta substitui o `.booking-flow`
//      atual — a MESMA troca de servidor que já existia (a URL ainda decide
//      tudo: serviço, profissional, data, extras), só sem recarregar a
//      página. `history.pushState` mantém a URL e o botão Voltar do
//      navegador coerentes com a etapa mostrada — sem isto, apertar Voltar
//      deixaria a URL e o cartão visível dessincronizados.
//
//   2. Revela a confirmação dentro da etapa fundida quando um horário é
//      escolhido (`revealConfirm`) — sem requisição nenhuma, porque a
//      confirmação já está nesta mesma resposta, só escondida por
//      `[hidden]`. `hideConfirm` desfaz, para "Trocar horário".
//
//   3. Mostra/escabonde o painel "+ Adicionar serviço" (`showAddService`/
//      `hideAddService`) sem perder o progresso: o painel é a mesma lista
//      densa de serviços (`_service_rows`, `mode: :add_extra`), e cada item
//      dela é um link comum `data-step-link` que soma o serviço aos
//      `extra_service_ids[]` já escolhidos e recarrega/troca a tela — a
//      lógica de "não perder o que já foi escolhido" vem inteira do servidor,
//      que já sabia somar extras antes desta tarefa.
//
// Sem JavaScript, nada disto roda: os links e formulários navegam
// normalmente (todos já levam `data-turbo="false"`), a página recarrega, e a
// etapa fundida mostra as duas sub-telas (data/horário e confirmação)
// empilhadas em vez de uma escondida — a mesma degradação graciosa que o
// projeto já tinha antes do card único (ver a skill
// `barber-scheduler-js-toolchain`: o POST por `curl` continua completando um
// agendamento sem nenhum JS carregado).
export default class extends Controller {
  static targets = [ "schedulePanel", "confirmPanel", "addServicePanel" ]

  connect() {
    // Se a tela já chegou com um horário escolhido (reenvio de formulário
    // inválido, ou um link com `start_at` pré-marcado), a confirmação já deve
    // abrir direto — sem isto o cliente veria a agenda de novo depois de já
    // ter escolhido um horário.
    if (this.hasConfirmPanelTarget && this.element.querySelector("input[name='appointment[start_at]']:checked")) {
      this.revealConfirm()
    }
  }

  // Delegado no elemento raiz (`data-action="click->booking-wizard#interceptLink"`)
  // porque o cartão troca de conteúdo o tempo todo — um listener por link
  // morreria a cada troca, e o delegado sobrevive porque está no container.
  interceptLink(event) {
    const link = event.target.closest("[data-step-link]")
    if (!link || link.tagName !== "A") return

    event.preventDefault()
    this.navigate(link.href)
  }

  interceptForm(event) {
    const form = event.target.closest("[data-step-link]")
    // Só formulários GET participam da troca de etapa sem navegação: um POST
    // (a confirmação final) precisa do ciclo de requisição completo, com
    // redirecionamento para a página de recibo — interceptá-lo aqui
    // produziria um "sucesso" que nunca chegou ao servidor.
    if (!form || form.tagName !== "FORM" || form.method.toLowerCase() !== "get") return

    event.preventDefault()
    const params = new URLSearchParams(new FormData(form))
    const url = new URL(form.action, window.location.origin)
    url.search = params.toString()
    this.navigate(url.toString())
  }

  async navigate(url) {
    this.element.setAttribute("aria-busy", "true")

    try {
      const response = await fetch(url, { headers: { Accept: "text/html" } })
      if (!response.ok && response.status !== 423) throw new Error("Falha ao trocar de etapa.")

      const html = await response.text()
      const parsed = new DOMParser().parseFromString(html, "text/html")
      const novoCartao = parsed.querySelector(".booking-flow")
      if (!novoCartao) throw new Error("Resposta sem cartão de agendamento.")

      // `outerHTML` (e não `innerHTML`) porque o `data-step` e o
      // `data-controller` vivem no próprio elemento `.booking-flow` — trocar
      // só o conteúdo interno deixaria o `data-step` da etapa anterior
      // gravado no elemento, e a barra de progresso leria a etapa errada até
      // a próxima troca.
      this.element.outerHTML = novoCartao.outerHTML
      window.history.pushState({}, "", url)
    } catch (error) {
      this.element.removeAttribute("aria-busy")
      // A navegação comum é a rede de segurança: se o fetch falhar (rede
      // instável, 5xx), seguir o link de verdade garante que o cliente ainda
      // chega à etapa seguinte, só com um recarregamento de página.
      window.location.assign(url)
    }
  }

  revealConfirm() {
    if (this.hasSchedulePanelTarget) this.schedulePanelTarget.hidden = true
    if (this.hasConfirmPanelTarget) this.confirmPanelTarget.hidden = false
    this.markProgressStep("confirm")
  }

  hideConfirm() {
    if (this.hasConfirmPanelTarget) this.confirmPanelTarget.hidden = true
    if (this.hasSchedulePanelTarget) this.schedulePanelTarget.hidden = false
    this.markProgressStep("professional")
  }

  // A barra de progresso (`booking_progress`, em `appointments_helper.rb`) é
  // calculada no servidor a partir de `@booking_step`, que não muda quando
  // `revealConfirm`/`hideConfirm` só escondem/mostram painéis já presentes na
  // mesma resposta — sem isto a barra ficaria presa em "Profissional" mesmo
  // com a etapa de confirmação visível. Os dois nomes (`professional`,
  // `confirm`) são os dois últimos passos de `ORDEM_DO_FLUXO`; a troca é só
  // cosmética, e não reflete em nenhum parâmetro enviado ao servidor.
  markProgressStep(nomeAtivo) {
    const passos = this.element.querySelectorAll(".booking-progress .progress-step")
    const nomes = [ "unit", "service", "professional", "confirm" ]
    const alvo = nomes.indexOf(nomeAtivo)
    if (alvo === -1 || passos.length === 0) return

    passos.forEach((passo, index) => {
      const posicaoNaLista = nomes.length - passos.length + index
      passo.classList.remove("progress-step--active", "progress-step--todo")
      passo.removeAttribute("aria-current")

      if (posicaoNaLista < alvo) {
        // já passou: sem classe extra, o CSS padrão de "feito" já se aplica
      } else if (posicaoNaLista === alvo) {
        passo.classList.add("progress-step--active")
        passo.setAttribute("aria-current", "step")
      } else {
        passo.classList.add("progress-step--todo")
      }
    })
  }

  showAddService() {
    if (this.hasAddServicePanelTarget) this.addServicePanelTarget.hidden = false
    if (this.hasConfirmPanelTarget) this.confirmPanelTarget.hidden = true
  }

  hideAddService() {
    if (this.hasAddServicePanelTarget) this.addServicePanelTarget.hidden = true
    if (this.hasConfirmPanelTarget) this.confirmPanelTarget.hidden = false
  }
}
