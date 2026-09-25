require 'rails_helper'

RSpec.describe Appointments::PublicScheduler, type: :service do
  let(:professional) { Professional.create!(name: "Profissional Público") }
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

  it "returns a domain error when the database rejects a concurrent booking" do
    allow(Appointments::Scheduler).to receive(:call).and_raise(ActiveRecord::ExclusionViolation)

    result = described_class.call(
      name: "Maria da Silva",
      phone: "19999998888",
      professional: professional,
      service: service,
      start_at: start_at
    )

    expect(result).not_to be_persisted
    expect(result.errors[:base]).to include("Escolha outro horário disponível.")
    expect(Client.where(name: "Maria da Silva")).not_to exist
  end
end
