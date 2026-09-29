import { Controller } from "@hotwired/stimulus"

// Liga o "com" de cada linha ao botão Agendar da mesma linha.
//
// O seletor sozinho não faz nada: ele é um `<select>` comum, e o agendamento
// acontece por link. Sem reescrever o `href`, escolher um profissional e
// clicar em Agendar levaria à mesma página de sempre, e o atalho seria
// decorativo — o pior tipo de bug, porque parece funcionar.
export default class extends Controller {
  // Cada linha tem o seu select e o seu link, e o alvo do Stimulus é do
  // controller inteiro. Por isso o `selectTarget` não serve aqui: com seis
  // linhas, ele seria o primeiro select da página, e escolher na quarta
  // reescreveria o botão da primeira. O `closest` na linha é o que garante
  // que o link reescrito é o da linha que o cliente tocou.
  selectProfessional(event) {
    const linha = event.target.closest("[data-service-agendar-row]")
    if (!linha) return

    const link = linha.querySelector("[data-service-agendar-target='link']")
    if (!link) return

    const profissional = event.target.value
    const url = new URL(link.href, window.location.origin)

    if (profissional) {
      url.searchParams.set("professional", profissional)
    } else {
      // Sem profissional escolhido o parâmetro é removido, e não enviado
      // vazio: `?professional=` na URL faz o `new` cair no caminho de
      // "nenhum profissional escolhido" em vez do caminho de "escolha um".
      url.searchParams.delete("professional")
    }

    link.href = url.toString()
  }
}
