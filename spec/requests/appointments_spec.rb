require 'rails_helper'

RSpec.describe "Appointments", type: :request do
  let(:professional) { Professional.create!(name: "Profissional Teste") }
  let(:client) { Client.create!(name: "Cliente Teste", phone: "11999999999") }
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

  before do
    create_test_appointment!(professional: professional, client: client, service: service,
                        start_at: start_at, end_at: start_at + 30.minutes)
  end

  describe "GET /appointments" do
    it "returns http success" do
      get appointments_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /appointments/confirmation/:token" do
    # Este helper roda dentro do exemplo, e um `get` anterior já limpou Current
    # pelo RequestStore::Middleware. Criar um Appointment aqui exige o tenant explícito,
    # senão a linha nasceria órfã e a validação recusaria.
    def finished_appointment(status)
      within_tenant do
        slot = 10.days.from_now.change(hour: 10, min: 0, sec: 0)
        appointment = create_test_appointment!(professional: professional, client: client, service: service,
                                          start_at: slot, end_at: slot + 30.minutes)
        appointment.update_columns(status: status)
        appointment
      end
    end

    it "redirects away without rendering customer data for a finished appointment" do
      results = %w[canceled completed].map do |status|
        get "/appointments/confirmation/#{finished_appointment(status).confirmation_token}"
        [ response.status, response.body.include?(client.name) ]
      end

      expect(results).to eq([ [ 302, false ], [ 302, false ] ])
    end
  end

  describe "GET /appointments/new" do
    it "returns http success" do
      get new_appointment_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /appointments" do
    def create_params
      new_start = 2.days.from_now.change(hour: 9, min: 0)
      params = {
        appointment: {
          service_id: service.id,
          professional_id: professional.id,
          date: new_start.to_date.iso8601,
          start_at: new_start.iso8601,
          client_name: "Visitante Teste",
          client_phone: "11988887777"
        }
      }
      params
    end

    it "creates an appointment" do
      expect {
        post appointments_path(unidade_slug: test_unit_for(test_barbershop).slug), params: create_params
      }.to change_tenant_count(Appointment).by(1)
    end

    it "redirects to the protected confirmation" do
      post appointments_path(unidade_slug: test_unit_for(test_barbershop).slug), params: create_params

      expect(response).to redirect_to(appointment_confirmation_path(token: tenant_records(Appointment).last.confirmation_token))
    end

    it "renders the booking form when the appointment is invalid" do
      params = { appointment: { service_id: nil, professional_id: nil, date: nil, start_at: nil } }

      post appointments_path(unidade_slug: test_unit_for(test_barbershop).slug), params: params

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
