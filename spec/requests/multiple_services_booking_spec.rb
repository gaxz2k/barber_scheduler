require "rails_helper"

RSpec.describe "Agendamento público com múltiplos serviços", type: :request do
  let(:principal) { Service.create!(name: "Corte", duration_minutes: 30, price_cents: 5000) }
  let(:barba) { Service.create!(name: "Barba", duration_minutes: 20, price_cents: 3000) }
  let(:professional) { Professional.create!(name: "Gustavo") }
  let(:tomorrow) { Date.current + 1 }
  let(:unidade_slug) { test_unit_for(test_barbershop).slug }

  before do
    Appointment.delete_all
    Service.delete_all
    Professional.delete_all
    Client.delete_all
  end

  def available_start
    tomorrow.in_time_zone.change(hour: 9, min: 0)
  end

  def booking_params(extra_service_ids: [])
    {
      appointment: {
        service_id: principal.id,
        professional_id: professional.id,
        date: tomorrow.iso8601,
        start_at: available_start.iso8601,
        client_name: "Maria da Silva",
        client_phone: "19999998888",
        extra_service_ids: extra_service_ids
      }
    }
  end

  def created_appointment
    Appointment.without_tenant_scope.last
  end

  def post_booking(extra_service_ids: [])
    principal
    professional
    post appointments_path(unidade_slug: unidade_slug), params: booking_params(extra_service_ids: extra_service_ids)
  end

  it "shows the extra service as an option on the booking screen" do
    principal
    barba
    professional

    get new_unidade_appointment_path(unidade_slug, service: principal.id)

    expect(response.body).to include("Barba")
  end

  it "shows the combined total when an extra is selected" do
    principal
    barba
    professional

    get new_unidade_appointment_path(unidade_slug, service: principal.id, extra_service_ids: [ barba.id ])

    expect(response.body).to include("R$ 80,00")
  end

  it "creates the appointment linked to the extra service" do
    barba
    post_booking(extra_service_ids: [ barba.id ])

    registros = AppointmentService.where(appointment_id: created_appointment.id).pluck(:service_id)

    expect(registros).to eq([ barba.id ])
  end

  it "reserves a 60-minute block when the extra rounds the duration up" do
    barba
    post_booking(extra_service_ids: [ barba.id ])

    expect(created_appointment.end_at - created_appointment.start_at).to eq(60.minutes)
  end

  it "ignores an extra service id from another barbershop" do
    outra_barbearia = Barbershop.create!(name: "Outra", slug: "outra-#{SecureRandom.hex(4)}")
    servico_de_outra = within_tenant(outra_barbearia) { Service.create!(name: "Sobrancelha", duration_minutes: 15) }
    post_booking(extra_service_ids: [ servico_de_outra.id ])

    expect(AppointmentService.where(appointment_id: created_appointment.id)).to be_empty
  end
end
