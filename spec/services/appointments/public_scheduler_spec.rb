require 'rails_helper'

RSpec.describe Appointments::PublicScheduler, type: :service do
  let(:professional) { Professional.create!(name: "Profissional Público") }
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

  def schedule(name: "Maria da Silva", phone: "19999998888")
    described_class.call(
      name: name,
      phone: phone,
      professional: professional,
      service: service,
      start_at: start_at
    )
  end

  it "creates the client and appointment from visitor data" do
    result = schedule

    expect(result).to be_persisted
    expect(result.client.name).to eq("Maria da Silva")
    expect(result.client.phone).to eq("19999998888")
  end

  it "normalizes punctuation in the phone number" do
    result = schedule(phone: "(19) 99999-8888")

    expect(result).to be_persisted
    expect(result.client.phone).to eq("19999998888")
  end

  it "returns a domain error when the visitor data is missing" do
    result = schedule(name: "", phone: "123")

    expect(result).not_to be_persisted
    expect(result.errors[:base]).to include("Informe seu nome e um telefone válido.")
  end

  it "returns a domain error when the phone is invalid" do
    result = schedule(phone: "123")

    expect(result).not_to be_persisted
    expect(result.errors[:base]).to include("Informe seu nome e um telefone válido.")
  end

  it "does not persist a client when scheduling fails" do
    result = schedule(phone: "123")

    expect(result).not_to be_persisted
    expect(Client.where(name: "Maria da Silva")).not_to exist
  end
end
