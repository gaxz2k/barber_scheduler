require "rails_helper"

# O caminho fundido: o cliente escolhe o serviço, vê a agenda de cada
# profissional e manda o par (quem, quando) em um só campo.
RSpec.describe "agendamento com profissional e horário na mesma tela", type: :request do
  let(:barbearia) { Barbershop.create!(name: "Agenda Unida", slug: "agenda-unida-#{SecureRandom.hex(3)}") }
  let(:unidade) { test_unit_for(barbearia) }
  let(:servico) { within_tenant(barbearia) { Service.create!(name: "Corte", duration_minutes: 30) } }
  let(:profissional) { within_tenant(barbearia) { Professional.create!(name: "Bruno") } }
  # Amanhã, e não hoje: a agenda de hoje já começou a correr, e um slot às 9h
  # de hoje pode estar no passado dependendo de que horas o teste roda.
  let(:data) { Date.current + 1 }
  let(:host) { { "HTTP_HOST" => tenant_host(barbearia) } }

  # Os dois profissionais são criados antes da requisição porque o `let` é
  # lazy: quem aparece na URL precisa existir, e o registro só nasceria dentro
  # do `expect` — depois da requisição que deveria mostrar o nome dele.
  before do
    servico
    profissional
  end

  # O que o navegador envia: um único `start_at` com `profissional_id|horario`.
  # Este exemplo é o que faltava — sem ele, os 328 exemplos passavam e o
  # agendamento pelo formulário real voltava para a lista de serviços.
  it "confirma o agendamento mandando o par profissional e horário" do
    inicio = data.in_time_zone.change(hour: 9, min: 0)

    post appointments_path(unidade_slug: unidade.slug),
         params: {
           appointment: {
             service_id: servico.id,
             date: data.iso8601,
             start_at: "#{profissional.id}|#{inicio.iso8601}",
             client_name: "Maria",
             client_phone: "19999998888"
           }
         },
         headers: host

    agendamento = Appointment.without_tenant_scope.last
    expect(agendamento.professional_id).to eq(profissional.id)
    expect(agendamento.barbershop_unit_id).to eq(unidade.id)
  end

  # O horário que este teste manda não existe na grade: 03:00 está fora de
  # qualquer expediente, mesmo com a janela larga que o cenário cria. Escolher
  # "9h + 7h" não serviria — 16:00 é um horário normal, e o teste passaria sem
  # provar nada.
  it "recusa um horário que não existe na agenda daquele profissional" do
    inexistente = data.in_time_zone.change(hour: 3, min: 0)

    post appointments_path(unidade_slug: unidade.slug),
         params: {
           appointment: {
             service_id: servico.id,
             date: data.iso8601,
             start_at: "#{profissional.id}|#{inexistente.iso8601}",
             client_name: "Maria",
             client_phone: "19999998888"
           }
         },
         headers: host

    expect(Appointment.without_tenant_scope.where(professional_id: profissional.id)).to be_empty
  end

  it "mostra a agenda de todos os profissionais do serviço escolhido" do
    outro = within_tenant(barbearia) { Professional.create!(name: "Camila") }

    # Com a data: sem ela a tela ainda não sabe que dia mostrar, e não há
    # agenda para listar. A escolha do dia é o que libera as grades.
    get new_unidade_appointment_path(unidade.slug, service: servico.id, date: data.iso8601),
        headers: host

    # Deixa claro o que a tela mostrou, para a falha dizer onde parou.
    expect(response.body).to include("agenda-card", profissional.name, outro.name)
  end

  # O "com" da lista de serviços é o atalho que o usuário pediu: escolher
  # serviço e profissional na mesma linha. Este exemplo cobre o outro lado do
  # atalho — que escolher um profissional mostra só a agenda dele, e não as
  # de todo mundo, porque é o que a escolha significa.
  it "mostra só a agenda do profissional escolhido na lista de serviços" do
    within_tenant(barbearia) { Professional.create!(name: "Camila") }

    get new_unidade_appointment_path(unidade.slug, service: servico.id,
                                     professional: profissional.id, date: data.iso8601),
        headers: host

    expect(response.body).to include(profissional.name)
    expect(response.body).not_to include("Camila")
  end

  # E o caminho de volta: quem se arrependeu do profissional precisa chegar na
  # comparação de todo mundo de novo. O link existe e não carrega o
  # profissional — é isso que devolve a agenda completa.
  it "oferece voltar para a agenda de todos depois de escolher um" do
    get new_unidade_appointment_path(unidade.slug, service: servico.id,
                                     professional: profissional.id, date: data.iso8601),
        headers: host

    # O link existe, aponta para a mesma tela sem o profissional e traz "ver
    # todos" — é o que devolve a comparação. O `include` é sobre o array
    # inteiro de propósito: o scan devolve o texto, e comparar com o primeiro
    # elemento só funcionaria se houvesse exatamente um link na página.
    links = CGI.unescapeHTML(response.body).scan(/<a[^>]+href="([^"]*)"[^>]*>ver todos</).flatten
    expect(links).not_to be_empty
    expect(links).to all(include("service=#{servico.id}"))
    expect(links).to all(satisfy { |url| url.exclude?("professional") })
  end
end
