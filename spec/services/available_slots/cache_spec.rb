require 'rails_helper'

RSpec.describe AvailableSlots::Cache, type: :service do
  let(:professional) { Professional.create!(name: "Profissional Teste") }
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:date) { Date.current + 1 }
  let(:calculator) { instance_spy(AvailableSlots::Calculator) }
  let(:redis) { MockRedis.new }

  before do
    allow(Rails.application.config.x).to receive(:redis).and_return(redis)
    allow(AvailableSlots::Calculator).to receive(:new).and_return(calculator)
    allow(calculator).to receive(:call).and_return([ date.in_time_zone.change(hour: 9, min: 0) ])
  end

  def fetch(date: self.date, service: self.service)
    described_class.fetch(professional: professional, date: date, service: service)
  end

  describe ".fetch" do
    it "stores calculated slots in Redis" do
      fetch

      expect(redis.keys).not_to be_empty
    end

    it "reuses cached slots without recalculating" do
      fetch
      fetch

      expect(AvailableSlots::Calculator).to have_received(:new).once
    end

    it "rejects a blank date" do
      expect { fetch(date: nil) }.to raise_error(ArgumentError, /date/i)
    end

    it "rejects a blank service" do
      expect { fetch(service: nil) }.to raise_error(ArgumentError, /service/i)
    end
  end
end
