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

  def client
    @client ||= Client.create!(name: "Cliente Teste", phone: "11999999999")
  end

  def fetch(date: self.date, service: self.service, professional: self.professional)
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

    it "does not cache slots for today" do
      today = Date.current

      first_slots = fetch(date: today)
      second_slots = fetch(date: today)

      expect(first_slots).to eq(second_slots)
      expect(AvailableSlots::Calculator).to have_received(:new).twice
    end

    it "recalculates when the service duration changes" do
      fetch
      service.duration_minutes = 45
      service.save!(validate: false)
      fetch

      expect(AvailableSlots::Calculator).to have_received(:new).twice
    end

    it "deletes the exact cache key on invalidation" do
      cache = described_class.new(professional: professional, date: date, service: service)
      fetch
      key = redis.keys.find do |redis_key|
        !redis_key.end_with?(":generation")
      end

      cache.invalidate

      expect(redis.get(key)).to be_nil
    end

    it "does not fail the appointment transaction when Redis is unavailable" do
      allow(redis).to receive(:del).and_raise(Redis::CannotConnectError, "offline")

      expect do
        appointment = Appointment.create!(
          client: client,
          professional: professional,
          service: service,
          start_at: date.in_time_zone.change(hour: 9, min: 0),
          end_at: date.in_time_zone.change(hour: 9, min: 30)
        )

        expect(appointment).to be_persisted
      end.not_to raise_error
    end

    it "does not repopulate the cache after an appointment invalidates a stale calculation" do
      cache = described_class.new(professional: professional, date: date, service: service)
      calculated_slots = [ date.in_time_zone.change(hour: 9, min: 0) ]
      cache_key = [
        "available-slots",
        professional.id,
        date.to_date,
        service.id,
        service.duration_minutes
      ].join(":")
      generation_key = "#{cache_key}:generation"
      allow(calculator).to receive(:call) do
        cache.invalidate
        calculated_slots
      end

      result = fetch

      expect(result).to eq(calculated_slots)
      expect(redis.get(cache_key)).to be_nil
      expect(redis.get(generation_key)).to eq("1")
    end

    it "recalculates after an appointment is created" do
      start_at = date.in_time_zone.change(hour: 9, min: 0)

      fetch
      appointment = Appointment.new(
        client: client,
        professional: professional,
        service: service,
        start_at: start_at,
        end_at: start_at + service.duration_minutes.minutes
      )
      appointment.save!

      fetch

      expect(AvailableSlots::Calculator).to have_received(:new).twice
    end

    it "recalculates after the appointment status changes" do
      start_at = date.in_time_zone.change(hour: 9, min: 0)
      appointment = Appointment.create!(
        client: client,
        professional: professional,
        service: service,
        start_at: start_at,
        end_at: start_at + service.duration_minutes.minutes
      )
      fetch

      appointment.cancel!
      fetch

      expect(AvailableSlots::Calculator).to have_received(:new).twice
    end

    it "recalculates after the appointment professional changes" do
      start_at = date.in_time_zone.change(hour: 9, min: 0)
      other_professional = Professional.create!(name: "Profissional Outro")
      appointment = Appointment.create!(
        client: client,
        professional: professional,
        service: service,
        start_at: start_at,
        end_at: start_at + service.duration_minutes.minutes
      )
      fetch
      old_key = redis.keys.find do |redis_key|
        redis_key.start_with?("available-slots") && !redis_key.end_with?(":generation")
      end

      appointment.update!(professional: other_professional)
      fetch(professional: other_professional)

      expect(redis.get(old_key)).to be_nil
      expect(AvailableSlots::Calculator).to have_received(:new).twice
    end

    it "recalculates after the appointment is destroyed" do
      start_at = date.in_time_zone.change(hour: 9, min: 0)
      appointment = Appointment.create!(
        client: client,
        professional: professional,
        service: service,
        start_at: start_at,
        end_at: start_at + service.duration_minutes.minutes
      )
      fetch

      appointment.destroy!
      fetch

      expect(AvailableSlots::Calculator).to have_received(:new).twice
    end

    it "recalculates after the appointment service changes" do
      start_at = date.in_time_zone.change(hour: 9, min: 0)
      other_service = Service.create!(name: "Barba", duration_minutes: 30)
      appointment = Appointment.create!(
        client: client,
        professional: professional,
        service: service,
        start_at: start_at,
        end_at: start_at + service.duration_minutes.minutes
      )
      fetch
      old_key = redis.keys.find do |redis_key|
        redis_key.start_with?("available-slots") && !redis_key.end_with?(":generation")
      end

      appointment.update!(service: other_service)
      fetch(service: other_service)

      expect(redis.get(old_key)).to be_nil
      expect(AvailableSlots::Calculator).to have_received(:new).twice
    end

    it "rejects a blank date" do
      expect { fetch(date: nil) }.to raise_error(ArgumentError, /date/i)
    end

    it "rejects a blank service" do
      expect { fetch(service: nil) }.to raise_error(ArgumentError, /service/i)
    end
  end
end
