require "rails_helper"

# A unidade atravessa o agendamento inteiro, e a URL é o que a carrega.
#
# `Appointments::Scheduler` exige a unidade, e ela vem de
# `params[:unidade_slug]`. Se a view que lista os serviços gerar o link sem
# esse parâmetro, o cliente escolhe o serviço, escolhe o profissional, escolhe
# o horário — e só no `create` recebe "Escolha a unidade". A falha aparece
# depois de três cliques, e cada passo do caminho é o mesmo bug: um link que
# perde o que a URL carregava.
#
# O que este spec prova é a propagação: cada link do caminho entrega a unidade
# adiante. Um spec que só conferisse a agenda do último passo passaria com a
# home quebrada e o cliente perdendo a escolha na etapa 2.
RSpec.describe "a unidade sobrevive às etapas do agendamento", type: :request do
  let!(:barbearia) { Barbershop.create!(name: "Barbearia Etapas", slug: "etapas-#{SecureRandom.hex(4)}") }
  let!(:unidade) { test_unit_for(barbearia) }
  let(:servico) { within_tenant(barbearia) { Service.create!(name: "Corte #{SecureRandom.hex(2)}", duration_minutes: 30) } }
  let!(:profissional) do
    within_tenant(barbearia) { Professional.create!(name: "Prof #{SecureRandom.hex(2)}", barbershop_unit: unidade) }
  end
  let(:data) { (Date.current + 3).to_s }
  let(:host) { { "HTTP_HOST" => tenant_host(barbearia) } }

  # O serviço é criado em todo exemplo porque cada um deles pede a página que o
  # lista. Um `let` lazy devolveria a tela de "nenhum serviço cadastrado", e o
  # exemplo falharia por um motivo que não é o que ele testa.
  before { servico }

  # O caminho tem duas entradas. Na raiz, quando a barbearia tem mais de uma
  # loja com expediente, o cliente começa escolhendo a unidade; com uma
  # unidade só, ele já sabe onde vai e começa pelo serviço. Nos dois casos a
  # unidade precisa estar no link, senão o agendamento é recusado no fim.
  #
  # A unidade aparece de duas formas e as duas contam: na raiz de quem tem
  # várias lojas, a escolha é o próprio caminho (`/barbearia/unidades/<slug>`);
  # em qualquer outra etapa, é o query param que sobrevive ao formulário.
  def caminho_da_unidade(selecao)
    selecao.include?("/barbearia/unidades/#{unidade.slug}") ||
      selecao.include?("unidade_slug=#{unidade.slug}")
  end

  # Os links de href que levam ao agendamento, já sem o escape de `&`.
  def links_de_agendamento
    response.body.scan(/href="([^"]*)"/).flatten
             .select { |href| href.include?("appointments/new") || href.include?("barbearia/unidades/") }
             .map { |href| CGI.unescapeHTML(href) }
  end

  it "a raiz leva o cliente a uma página que carrega a unidade" do
    get root_path, headers: host

    # Com uma unidade só a raiz mostra o serviço direto; com várias, mostra a
    # escolha de loja. As duas saídas precisam mencar a unidade.
    links = links_de_agendamento
    expect(links).not_to be_empty
    expect(links.map { |href| caminho_da_unidade(href) }).to all(be(true))
  end

  it "com várias lojas a raiz pergunta onde o cliente quer ser atendido" do
    jardim = within_tenant(barbearia) do
      BarbershopUnit.create!(barbershop: barbearia, name: "Jardim",
                             slug: "jardim-#{SecureRandom.hex(4)}",
                             opening_hours: { "1" => { "open" => "10:00", "close" => "18:00" } })
    end

    get root_path, headers: host

    expect(response.body).to include("Escolha onde quer ser atendido", "Jardim")
    expect(links_de_agendamento).to include("/barbearia/unidades/#{jardim.slug}")
  end

  it "a página da unidade entrega a unidade no link de serviço" do
    get "/barbearia/unidades/#{unidade.slug}", headers: host

    links = links_de_agendamento
    expect(links).not_to be_empty
    expect(links.map { |href| caminho_da_unidade(href) }).to all(be(true))
  end

  # Depois da fusão não existe mais link de profissional: a agenda vem toda na
  # tela do serviço escolhido. O que a unidade precisa é sobreviver no
  # formulário de data, que é a única navegação que sai dessa etapa — e é por
  # ela que o cliente troca o dia e recarrega a agenda.
  it "a etapa de serviço entrega a unidade no formulário de data" do
    get new_appointment_path(service: servico.id, unidade_slug: unidade.slug), headers: host

    expect(response.body).to include(caminho_da_unidade(new_appointment_path(service: servico.id)).to_s)
  end

  it "a etapa de profissional entrega a unidade no formulário" do
    get new_appointment_path(service: servico.id, professional: profissional.id,
                            date: data, unidade_slug: unidade.slug),
        headers: host

    expect(response.body).to include("unidade_slug=#{unidade.slug}")
  end

  it "o agendamento criado fica na unidade da URL" do
    slot = within_tenant(barbearia) do
      AvailableSlots::Calculator.new(professional: profissional, date: Date.parse(data),
                                      service: servico, barbershop_unit: unidade).call.first
    end

    post appointments_path(unidade_slug: unidade.slug),
         params: { appointment: { service_id: servico.id, professional_id: profissional.id,
                                   date: data, start_at: slot.iso8601,
                                   client_name: "Cliente Etapas", client_phone: "11987650021" } },
         headers: host

    expect(within_tenant(barbearia) { Appointment.order(:id).last.barbershop_unit_id }).to eq(unidade.id)
  end
end
