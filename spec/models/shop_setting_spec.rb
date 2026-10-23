require 'rails_helper'

RSpec.describe ShopSetting, type: :model do
  it "belongs to exactly one barbershop" do
    setting = within_tenant { described_class.create!(barbershop: test_barbershop) }

    expect(setting.barbershop).to eq(test_barbershop)
  end

  it "rejects a second setting for the same barbershop" do
    within_tenant { described_class.create!(barbershop: test_barbershop) }

    duplicate = within_tenant { described_class.new(barbershop: test_barbershop) }

    expect(duplicate).not_to be_valid
  end

  it "explains the duplicate barbershop with a clear error" do
    within_tenant { described_class.create!(barbershop: test_barbershop) }

    duplicate = within_tenant { described_class.new(barbershop: test_barbershop) }
    duplicate.valid?

    expect(duplicate.errors[:barbershop_id]).to include("já está em uso")
  end
end
