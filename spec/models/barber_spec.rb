require 'rails_helper'

RSpec.describe Barber, type: :model do
  it "is valid with name" do
    barber = described_class.new(name: "John Doe")
    expect(barber).to be_valid
  end

  it "is invalid without name" do
    barber = described_class.new(name: nil)
    expect(barber).not_to be_valid
  end

  it "is invalid with a duplicate name" do
    described_class.create(name: "John Doe")
    barber = described_class.new(name: "John Doe")
    expect(barber).not_to be_valid
  end

  it "is invalid with empty name" do
    barber = described_class.new(name: "")
    expect(barber).not_to be_valid
  end
end
