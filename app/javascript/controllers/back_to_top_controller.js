import { Controller } from "@hotwired/stimulus"

// Botão flutuante "voltar ao topo" do fluxo público de agendamento (ver o
// contexto do redesenho — a referência SimplesAgenda).
//
// Sem JavaScript o elemento é um `<a href="#top">` comum, sempre visível, e
// já funciona sozinho (salto abrupto em vez de suave) — ver o comentário em
// `shared/_back_to_top.html.erb`. Este controller só melhora dois detalhes
// quando JS está disponível: o scroll vira suave, e o botão fica escondido
// até o cliente ter rolado a página (o print de referência mostra o botão
// só "depois de rolar").
export default class extends Controller {
  connect() {
    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    this.element.classList.add("back-to-top--js")
    this.onScroll()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  onScroll() {
    const rolou = window.scrollY > 240
    this.element.classList.toggle("back-to-top--visible", rolou)
  }

  scrollToTop(event) {
    event.preventDefault()
    window.scrollTo({ top: 0, behavior: "smooth" })
  }
}
