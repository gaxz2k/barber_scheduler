require 'rails_helper'

RSpec.describe Appointment, type: :model do
  let(:professional) { Professional.create!(name: "Profissional Teste") }
  let(:client) { Client.create!(name: "Cliente Teste", phone: "123") }
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

  describe "attributes" do
    it "belongs to a professional" do
      appointment = described_class.create!(professional: professional, client: client, service: service,
                                            start_at: start_at, end_at: start_at + 30.minutes)

      expect(appointment.professional).to eq(professional)
    end
  end

  describe "start_at in the past" do
    subject(:appointment) do
      described_class.new(professional: professional, client: client, service: service,
                           start_at: 1.day.ago, end_at: 1.day.ago + 30.minutes)
    end

    it "is invalid" do
      expect(appointment).not_to be_valid
    end

    it "has an error on start_at" do
      appointment.valid?

      expect(appointment.errors[:start_at]).to include("não pode ser no passado")
    end
  end

  describe "overlapping appointment for the same professional" do
    subject(:overlapping) do
      described_class.new(professional: professional, client: client, service: service,
                           start_at: start_at + 15.minutes, end_at: start_at + 45.minutes)
    end

    before do
      described_class.create!(professional: professional, client: client, service: service,
                               start_at: start_at, end_at: start_at + 30.minutes)
    end

    it "is invalid" do
      expect(overlapping).not_to be_valid
    end

    it "has an error about the professional's schedule" do
      overlapping.valid?

      expect(overlapping.errors[:base]).to include("profissional já possui um agendamento nesse horário")
    end
  end

  describe "canceling a completed appointment" do
    subject(:appointment) do
      described_class.create!(professional: professional, client: client, service: service,
                               start_at: start_at, end_at: start_at + 30.minutes,
                               status: :completed)
    end

    it "raises an error" do
      expect { appointment.cancel! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "keeps the status as completed" do
      suppress(ActiveRecord::RecordInvalid) { appointment.cancel! }

      expect(appointment.reload.status).to eq("completed")
    end
  end
end
