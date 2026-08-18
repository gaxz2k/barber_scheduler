require 'rails_helper'

RSpec.describe Client, type: :model do
  it "is a valid client" do
    client = described_class.new(phone: "123-456-7890", name: "John Doe")
    expect(client).to be_valid
  end

  it "is invalid without a phone number" do
    client = described_class.new(phone: nil)
    expect(client).not_to be_valid
  end

  it "is invalid without a name" do
    client = described_class.new(name: nil)
    expect(client).not_to be_valid
  end
end
