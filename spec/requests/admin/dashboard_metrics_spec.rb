require "rails_helper"

# A home admin agora mostra um dashboard de métricas (total de clientes, taxa
# de cancelamento com tom, clientes por profissional) além do checklist de
# prontidão que já existia (ver `spec/requests/admin/setup_readiness_spec.rb`).
RSpec.describe "Dashboard de métricas da home admin", type: :request do
  let!(:barbearia) { Barbershop.create!(name: "Barbearia Métricas", slug: "metricas-#{SecureRandom.hex(4)}") }
  let(:unidade) { within_tenant(barbearia) { barbearia.unidades.order(:id).first } }
  let!(:admin) { create_admin_for(barbearia) }
  let(:profissional) { within_tenant(barbearia) { Professional.create!(name: "Gustavo", barbershop_unit: unidade) } }
  let(:cliente) { within_tenant(barbearia) { Client.create!(name: "Ana", phone: "11987650#{rand(100..999)}") } }

  before { sign_in admin }

  def criar_agendamento!(client:, professional:, status:, start_at: 1.day.ago)
    service = within_tenant(barbearia) { Service.find_or_create_by!(name: "Corte") { |s| s.duration_minutes = 30 } }
    appointment = within_tenant(barbearia) do
      Appointment.new(
        client: client, professional: professional, service: service, barbershop_unit: unidade,
        start_at: start_at, end_at: start_at + 30.minutes, status: :pending,
        confirmation_expires_at: 48.hours.from_now
      )
    end
    appointment.save!(validate: false)
    appointment.status = status
    appointment.save!(validate: false)
    appointment
  end

  # A home atual (home_path) para a barbearia, já autenticada como admin.
  def requisitar_home
    get admin_root_path, headers: { "HTTP_HOST" => tenant_host(barbearia) }
  end

  it "mostra o total de clientes cadastrados" do
    within_tenant(barbearia) { 2.times { |n| Client.create!(name: "Cliente #{n}", phone: "1198765010#{n}") } }

    requisitar_home

    expect(response.body).to include("Total de clientes")
  end

  it "mostra a tabela de clientes por profissional" do
    profissional

    requisitar_home

    expect(response.body).to include("Clientes por profissional")
  end

  it "calcula tom crítico para taxa de cancelamento alta" do
    3.times { criar_agendamento!(client: cliente, professional: profissional, status: :canceled) }

    requisitar_home

    expect(response.body).to include("badge--danger")
  end

  it "não afirma problema quando a taxa de cancelamento é baixa" do
    9.times { criar_agendamento!(client: cliente, professional: profissional, status: :completed) }
    criar_agendamento!(client: cliente, professional: profissional, status: :canceled)

    requisitar_home

    expect(response.body).not_to include("Atenção: taxa")
  end

  it "não vaza o status interno 'canceled' no texto renderizado" do
    criar_agendamento!(client: cliente, professional: profissional, status: :canceled)

    requisitar_home

    # O literal do enum não deve sobrar fora de atributo HTML (ex. a classe
    # CSS "badge--danger" não conta — o texto LIDO pelo operador, sim).
    corpo_sem_atributos = response.body.gsub(/class="[^"]*"/, "")
    expect(corpo_sem_atributos).not_to include("canceled")
  end

  it "mostra zero-state quando não há profissional cadastrado" do
    requisitar_home

    expect(response.body).to include("Nenhum profissional cadastrado ainda")
  end

  describe "isolamento entre barbearias" do
    it "métricas de uma barbearia não vazam para outra" do
      outra = Barbershop.create!(name: "Outra Barbearia Métricas", slug: "outra-metricas-#{SecureRandom.hex(4)}")
      within_tenant(outra) { Client.create!(name: "Cliente Alheio", phone: "11987650299") }

      requisitar_home

      expect(response.body).not_to include("Cliente Alheio")
    end

    it "profissionais de outra barbearia não aparecem na tabela" do
      outra = Barbershop.create!(name: "Outra Barbearia Métricas", slug: "outra-metricas-#{SecureRandom.hex(4)}")
      within_tenant(outra) { Professional.create!(name: "Profissional Alheio") }

      requisitar_home

      expect(response.body).not_to include("Profissional Alheio")
    end
  end
end
