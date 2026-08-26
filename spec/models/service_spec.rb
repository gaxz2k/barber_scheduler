require 'rails_helper'

RSpec.describe Service, type: :model do
  it "is valid with a name and a positive duration" do
    service = described_class.new(name: "Corte", duration_minutes: 30)

    expect(service).to be_valid
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
