require 'rails_helper'

RSpec.describe "Appointments", type: :request do
  let(:professional) { Professional.create!(name: "Profissional Teste") }
  let(:client) { Client.create!(name: "Cliente Teste", phone: "11999999999") }
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

  before do
    Appointment.create!(professional: professional, client: client, service: service,
                        start_at: start_at, end_at: start_at + 30.minutes)
  end

  describe "GET /appointments" do
    it "returns http success" do
      get appointments_path

      expect(response).to have_http_status(:success)
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
        post appointments_path, params: create_params
      }.to change(Appointment, :count).by(1)
    end

    it "redirects to the protected confirmation" do
      post appointments_path, params: create_params

      expect(response).to redirect_to(appointment_confirmation_path(token: Appointment.last.confirmation_token))
    end

    it "renders the booking form when the appointment is invalid" do
      params = { appointment: { service_id: nil, professional_id: nil, date: nil, start_at: nil } }

      post appointments_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
