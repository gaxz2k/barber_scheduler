require 'rails_helper'

RSpec.describe "Appointment com múltiplos serviços", type: :model do
  let(:principal) { Service.create!(name: "Corte", duration_minutes: 30, price_cents: 5000) }
  let(:barba) { Service.create!(name: "Barba", duration_minutes: 20, price_cents: 3000) }
  let(:professional) { Professional.create!(name: "Bruno") }
  let(:client) { Client.create!(name: "Cliente", phone: "19999998888") }
  let(:start_at) { 1.day.from_now.change(hour: 9, min: 0) }

  def build_appointment(extra_services: [])
    appointment = Appointment.new(
      client: client,
      professional: professional,
      service: principal,
      barbershop_unit: test_unit_for(test_barbershop),
      start_at: start_at,
      end_at: start_at + 30.minutes
    )
    extra_services.each { |extra| appointment.appointment_services.build(service: extra) }
    appointment
  end

  it "lists the main service alone when there are no extras" do
    appointment = build_appointment

    expect(appointment.all_services).to eq([ principal ])
  end

  it "lists the main service followed by the extras" do
    appointment = build_appointment(extra_services: [ barba ])

    expect(appointment.all_services).to eq([ principal, barba ])
  end

  it "does not round the duration when there is only the main service" do
    appointment = build_appointment

    expect(appointment.total_duration_minutes).to eq(30)
  end

  it "rounds the summed duration up to the next 30-minute slot" do
    appointment = build_appointment(extra_services: [ barba ])

    expect(appointment.total_duration_minutes).to eq(60)
  end

  it "sums the price of the main service and the extras" do
    appointment = build_appointment(extra_services: [ barba ])

    expect(appointment.total_price_cents).to eq(8000)
  end
end
