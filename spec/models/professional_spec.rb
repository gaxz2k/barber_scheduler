require 'rails_helper'

RSpec.describe Professional, type: :model do
  it "is valid with name" do
    professional = described_class.new(name: "Gustavo")
    expect(professional).to be_valid
  end

  it "is invalid without name" do
    professional = described_class.new(name: nil)
    expect(professional).not_to be_valid
  end

  it "is invalid with a duplicate name" do
    described_class.create!(name: "Gustavo")
    professional = described_class.new(name: "Gustavo")
    expect(professional).not_to be_valid
  end

  it "is invalid with empty name" do
    professional = described_class.new(name: "")
    expect(professional).not_to be_valid
  end
end
