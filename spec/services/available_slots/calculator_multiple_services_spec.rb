require 'rails_helper'

RSpec.describe "AvailableSlots::Calculator com serviços extras", type: :service do
  let(:professional) { Professional.create!(name: "Profissional Teste") }
  let(:client) { Client.create!(name: "Cliente Teste", phone: "11987654321") }
  let(:principal) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:barba) { Service.create!(name: "Barba", duration_minutes: 20) }
  let(:date) { Date.current + 1 }

  def calculate(extra_services: [])
    AvailableSlots::Calculator.new(
      professional: professional,
      date: date,
      service: principal,
      extra_services: extra_services,
      barbershop_unit: test_unit_for(test_barbershop)
    ).call
  end

  def occupy!(start_time)
    create_test_appointment!(
      client: client,
      professional: professional,
      service: principal,
      start_at: start_time,
      end_at: start_time + Scheduling::SLOT_DURATION
    )
  end

  it "does not offer a start whose combined block overlaps a busy slot" do
    occupy!(date.in_time_zone.change(hour: 9, min: 30))

    expect(calculate(extra_services: [ barba ])).not_to include(date.in_time_zone.change(hour: 9, min: 0))
  end

  it "still offers that same start for the service alone" do
    occupy!(date.in_time_zone.change(hour: 9, min: 30))

    expect(calculate).to include(date.in_time_zone.change(hour: 9, min: 0))
  end

  it "offers a start whose combined block is entirely free" do
    occupy!(date.in_time_zone.change(hour: 11, min: 0))

    expect(calculate(extra_services: [ barba ])).to include(date.in_time_zone.change(hour: 9, min: 0))
  end
end
