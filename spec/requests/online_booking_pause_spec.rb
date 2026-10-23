require "rails_helper"

RSpec.describe "Agendamento online pausado", type: :request do
  let(:barbearia) { Barbershop.create!(name: "Barbearia Pausa Pública", slug: "pausa-publica-#{SecureRandom.hex(3)}") }
  let(:unidade) { test_unit_for(barbearia) }
  let(:servico) { within_tenant(barbearia) { Service.create!(name: "Corte", duration_minutes: 30) } }
  let(:profissional) { within_tenant(barbearia) { Professional.create!(name: "Bruno") } }
  let(:data) { Date.current + 1 }

  def host
    { "HTTP_HOST" => tenant_host(barbearia) }
  end

  before do
    servico
    profissional
    within_tenant(barbearia) do
      ShopSetting.create!(barbershop: barbearia, online_booking_enabled: false, online_booking_message: "Voltamos amanhã.")
    end
  end

  def novo_agendamento_params
    inicio = data.in_time_zone.change(hour: 9, min: 0)
    {
      appointment: {
        service_id: servico.id,
        date: data.iso8601,
        start_at: "#{profissional.id}|#{inicio.iso8601}",
        client_name: "Maria",
        client_phone: "19999998888"
      }
    }
  end

  it "recusa a tela de novo agendamento com 423" do
    get new_unidade_appointment_path(unidade.slug, service: servico.id), headers: host

    expect(response).to have_http_status(:locked)
  end

  it "mostra a mensagem de pausa na tela de novo agendamento" do
    get new_unidade_appointment_path(unidade.slug, service: servico.id), headers: host

    expect(response.body).to include("Voltamos amanhã.")
  end

  it "recusa a criação do agendamento com 423" do
    post appointments_path(unidade_slug: unidade.slug), params: novo_agendamento_params, headers: host

    expect(response).to have_http_status(:locked)
  end

  it "não persiste o agendamento quando pausado" do
    expect {
      post appointments_path(unidade_slug: unidade.slug), params: novo_agendamento_params, headers: host
    }.not_to change_tenant_count(Appointment)
  end

  it "recusa a consulta de disponibilidade com 423 em JSON" do
    get unidade_availability_path(unidade.slug, service_id: servico.id, professional_id: profissional.id, date: data.iso8601),
        headers: host

    expect(response).to have_http_status(:locked)
  end

  it "devolve a mensagem de pausa no JSON de disponibilidade" do
    get unidade_availability_path(unidade.slug, service_id: servico.id, professional_id: profissional.id, date: data.iso8601),
        headers: host

    expect(response.parsed_body["error"]).to eq("Voltamos amanhã.")
  end

  it "ainda abre a home" do
    get root_path, headers: host

    expect(response).to have_http_status(:ok)
  end

  it "mostra o aviso de pausa na home" do
    get root_path, headers: host

    expect(response.body).to include("Agendamento online pausado", "Voltamos amanhã.")
  end
end
