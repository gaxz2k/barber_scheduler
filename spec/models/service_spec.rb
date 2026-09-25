require 'rails_helper'

RSpec.describe Service, type: :model do
  it "is valid with a name and a positive duration" do
    service = described_class.new(name: "Corte", duration_minutes: 30)

    expect(service).to be_valid
  end

  describe "with a duration of 45 minutes" do
    subject(:service) { described_class.new(name: "Corte", duration_minutes: 45) }

    it "is valid" do
      expect(service).to be_valid
    end
  end

  describe "without a name" do
    subject(:service) { described_class.new(name: nil, duration_minutes: 30) }

    it "is invalid" do
      expect(service).not_to be_valid
    end

    it "has an error on name" do
      service.valid?

      expect(service.errors[:name]).to include("não pode ficar em branco")
    end
  end

  describe "without a duration" do
    subject(:service) { described_class.new(name: "Corte", duration_minutes: nil) }

    it "is invalid" do
      expect(service).not_to be_valid
    end

    it "has an error on duration_minutes" do
      service.valid?

      expect(service.errors[:duration_minutes]).to include("não pode ficar em branco")
    end
  end

  describe "with a non-integer duration" do
    subject(:service) { described_class.new(name: "Corte", duration_minutes: 30.5) }

    it "is invalid" do
      expect(service).not_to be_valid
    end

    it "has an error on duration_minutes" do
      service.valid?

      expect(service.errors[:duration_minutes]).to include("não é um número inteiro")
    end
  end

  describe "changing the duration" do
    let(:service) { described_class.create!(name: "Corte", duration_minutes: 30) }
    let(:client) { Client.create!(name: "Cliente Teste", phone: "11987654321") }
    let(:professional) { Professional.create!(name: "Profissional Teste") }
    let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

    before do
      Appointment.create!(
        client: client,
        professional: professional,
        service: service,
        start_at: start_at,
        end_at: start_at + service.duration_minutes.minutes
      )
    end

    it "rejects changing the duration when appointments already exist" do
      service.duration_minutes = 45

      expect(service).not_to be_valid
    end

    it "adds an error when changing the duration with appointments" do
      service.duration_minutes = 45
      service.valid?

      expect(service.errors[:duration_minutes]).to include("não pode ser alterado quando existem agendamentos")
    end

    it "allows changing other attributes when appointments already exist" do
      service.name = "Corte premium"

      expect(service).to be_valid
    end
  end

  describe "with a duration of zero or less" do
    subject(:service) { described_class.new(name: "Corte", duration_minutes: 0) }

    it "is invalid" do
      expect(service).not_to be_valid
    end

    it "has an error on duration_minutes" do
      service.valid?

      expect(service.errors[:duration_minutes]).to include("deve ser maior que 0")
    end
  end
end
