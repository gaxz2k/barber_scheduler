require 'rails_helper'

RSpec.describe User, type: :model do
  it "is not an admin by default" do
    user = described_class.create!(email: "user@example.com", password: "password123")

    expect(user.admin?).to be false
  end
end
