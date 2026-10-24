require 'rails_helper'

RSpec.describe "Appointments::Scheduler com múltiplos serviços", type: :service do
  let(:professional) { Professional.create!(name: "Profissional Teste") }
  let(:client) { Client.create!(name: "Cliente Teste", phone: "11987654321") }
  let(:principal) { Service.create!(name: "Corte", duration_minutes: 20) }
  let(:barba) { Service.create!(name: "Barba", duration_minutes: 20) }
  let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

  def schedule(extra_services: [])
    Appointments::Scheduler.call(
      client: client,
      professional: professional,
      service: principal,
      extra_services: extra_services,
      start_at: start_at,
      barbershop_unit: test_unit_for(test_barbershop)
    )
  end

  it "reserves the rounded sum of the main service and the extras" do
    result = schedule(extra_services: [ barba ])

    expect(result).to be_persisted
    expect(result.end_at).to eq(start_at + 60.minutes)
  end

  it "records the extra service on the appointment" do
    result = schedule(extra_services: [ barba ])

    expect(result.extra_services).to eq([ barba ])
  end

  it "does not round when there are no extras" do
    result = schedule

    expect(result.end_at).to eq(start_at + 20.minutes)
  end

  it "refuses when the combined block overlaps an existing appointment" do
    Appointment.create!(
      client: client,
      professional: professional,
      service: principal,
      barbershop_unit: test_unit_for(test_barbershop),
      start_at: start_at + 30.minutes,
      end_at: start_at + 50.minutes
    )

    result = schedule(extra_services: [ barba ])

    expect(result).not_to be_persisted
    expect(result.errors[:base]).to include("profissional já possui um agendamento nesse horário")
  end

  it "ignores a blank extra service" do
    result = schedule(extra_services: [ nil ])

    expect(result).to be_persisted
    expect(result.end_at).to eq(start_at + 20.minutes)
  end
end
