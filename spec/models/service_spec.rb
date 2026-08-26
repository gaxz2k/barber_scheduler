require 'rails_helper'

RSpec.describe Service, type: :model do
  it "is valid with a name and a positive duration" do
    service = described_class.new(name: "Corte", duration_minutes: 30)

    expect(service).to be_valid
  end

  it "is invalid without a name" do
    service = described_class.new(name: nil, duration_minutes: 30)

    expect(service).not_to be_valid
    expect(service.errors[:name]).to include("não pode ficar em branco")
  end

  it "is invalid without a duration" do
    service = described_class.new(name: "Corte", duration_minutes: nil)

    expect(service).not_to be_valid
    expect(service.errors[:duration_minutes]).to include("não pode ficar em branco")
  end

  it "is invalid when duration is not an integer" do
    service = described_class.new(name: "Corte", duration_minutes: 30.5)

    expect(service).not_to be_valid
    expect(service.errors[:duration_minutes]).to include("não é um número inteiro")
  end

  it "is invalid when duration is zero or negative" do
    service = described_class.new(name: "Corte", duration_minutes: 0)

    expect(service).not_to be_valid
    expect(service.errors[:duration_minutes]).to include("deve ser maior que 0")
  end
end
