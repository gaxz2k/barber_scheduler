require "rails_helper"

RSpec.describe Appointments::PhoneLookup, type: :service do
  def create_appointment(phone:, status: :pending, start_at: 1.day.from_now.change(hour: 10, min: 0))
    client = Client.create!(name: "Cliente", phone: phone)
    professional = Professional.create!(name: "Profissional")
    service = Service.create!(name: "Corte", duration_minutes: 30)
    Appointment.create!(
      client: client,
      professional: professional,
      service: service,
      barbershop_unit: test_unit_for(test_barbershop),
      start_at: start_at,
      end_at: start_at + 30.minutes,
      status: status
    )
  end

  it "finds appointments by the client's phone" do
    appointment = within_tenant { create_appointment(phone: "19999998888") }

    result = within_tenant { described_class.call(phone: "19999998888") }

    expect(result).to include(appointment)
  end

  it "normalizes punctuation in the phone before searching" do
    appointment = within_tenant { create_appointment(phone: "19999998888") }

    result = within_tenant { described_class.call(phone: "(19) 99999-8888") }

    expect(result).to include(appointment)
  end

  it "excludes canceled appointments" do
    within_tenant { create_appointment(phone: "19999998888", status: :canceled) }

    result = within_tenant { described_class.call(phone: "19999998888") }

    expect(result).to be_empty
  end

  it "returns nothing for a phone with no appointments" do
    result = within_tenant { described_class.call(phone: "19988887777") }

    expect(result).to be_empty
  end

  it "returns nothing for a blank phone" do
    result = within_tenant { described_class.call(phone: "") }

    expect(result).to be_empty
  end

  it "never crosses tenants" do
    appointment = within_tenant { create_appointment(phone: "19999998888") }

    result = within_tenant(other_barbershop) do
      Client.create!(name: "Outro Cliente", phone: "19999998888")
      described_class.call(phone: "19999998888")
    end

    expect(result).not_to include(appointment)
    expect(result).to be_empty
  end
end
