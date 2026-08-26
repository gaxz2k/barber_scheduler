require 'rails_helper'

RSpec.describe "Appointments", type: :request do
  let(:barber) { Barber.create!(name: "Barbeiro Teste") }
  let(:client) { Client.create!(name: "Cliente Teste", phone: "123") }
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }
  let!(:appointment) do
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
    it "creates an appointment and redirects" do
      new_start = 2.days.from_now.change(hour: 9, min: 0)

      expect {
        post appointments_path, params: {
          appointment: {
            client_id: client.id, barber_id: barber.id, service_id: service.id,
            start_at: new_start, end_at: new_start + 30.minutes
          }
        }
      }.to change(Appointment, :count).by(1)

      expect(response).to redirect_to(Appointment.last)
    end
  end

  describe "GET /appointments/:id/edit" do
    it "returns http success" do
      get edit_appointment_path(appointment)

      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /appointments/:id" do
    it "updates the appointment and redirects" do
      new_start = 3.days.from_now.change(hour: 11, min: 0)

      patch appointment_path(appointment), params: {
        appointment: { start_at: new_start, end_at: new_start + 30.minutes }
      }

      expect(response).to redirect_to(appointment)
      expect(appointment.reload.start_at).to eq(new_start)
    end
  end

  describe "DELETE /appointments/:id" do
    it "destroys the appointment and redirects" do
      expect {
        delete appointment_path(appointment)
      }.to change(Appointment, :count).by(-1)

      expect(response).to redirect_to(appointments_path)
    end
  end
end
