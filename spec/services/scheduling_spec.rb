require 'rails_helper'

RSpec.describe Scheduling do
  describe ".valid_slot?" do
    it "accepts a time on the half-hour grid" do
      time = Time.zone.parse("2030-01-01 10:30")

      expect(described_class.valid_slot?(time)).to be(true)
    end

    it "uses the configured application timezone" do
      expect(Time.zone.name).to eq("America/Sao_Paulo")
    end

    it "rejects a time between grid slots" do
      time = Time.zone.parse("2030-01-01 10:15")

      expect(described_class.valid_slot?(time)).to be(false)
    end

    it "rejects a time with seconds" do
      time = Time.zone.parse("2030-01-01 10:30:01")

      expect(described_class.valid_slot?(time)).to be(false)
    end
  end
end
