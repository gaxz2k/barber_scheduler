require 'rails_helper'

RSpec.describe "Appointments", type: :request do
  let(:barber) { Barber.create!(name: "Barbeiro Teste") }
  let(:client) { Client.create!(name: "Cliente Teste", phone: "123") }
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

  before do
    Appointment.create!(barber: barber, client: client, service: service,
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
      {
        appointment: {
          client_id: client.id, barber_id: barber.id, service_id: service.id,
          start_at: new_start, end_at: new_start + 30.minutes
        }
      }
    end

    it "creates an appointment" do
      expect {
        post appointments_path, params: create_params
      }.to change(Appointment, :count).by(1)
    end

    it "redirects to the new appointment" do
      post appointments_path, params: create_params

      expect(response).to redirect_to(Appointment.last)
    end
  end
end
