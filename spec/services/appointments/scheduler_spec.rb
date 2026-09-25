require 'rails_helper'

RSpec.describe Appointments::Scheduler, type: :service do
  let(:professional) { Professional.create!(name: "Profissional Teste") }
  let(:client) { Client.create!(name: "Cliente Teste", phone: "11987654321") }
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

  def schedule(start_time: start_at)
    described_class.call(
      client: client,
      professional: professional,
      service: service,
      start_at: start_time
    )
  end

  def occupy!(start_time)
    Appointment.create!(
      client: client,
      professional: professional,
      service: service,
      start_at: start_time,
      end_at: start_time + service.duration_minutes.minutes
    )
  end

  # Captures the real SQL issued while the block runs, so the specs can assert on the
  # SELECT ... FOR UPDATE the scheduler must take instead of stubbing the call.
  def sql_statements
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      statements << payload[:sql] unless payload[:name] == "SCHEMA"
    end
    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  describe ".call" do
    it "creates an appointment using the service duration" do
      result = schedule

      expect(result).to be_persisted
      expect(result.end_at).to eq(start_at + service.duration_minutes.minutes)
    end

    it "allows a service duration that spans more than one slot" do
      service.update!(duration_minutes: 45)

      result = schedule

      expect(result).to be_persisted
      expect(result.end_at).to eq(start_at + 45.minutes)
    end

    it "rejects a start time that is not aligned to the scheduling grid" do
      result = schedule(start_time: start_at + 5.minutes)

      expect(result).not_to be_persisted
      expect(result.errors[:start_at]).to include("não está alinhado à grade de horários")
    end

    it "derives end_at from the persisted duration when the given service copy is stale" do
      stale_service = Service.find(service.id)
      Service.find(service.id).update!(duration_minutes: 45)

      result = described_class.call(
        client: client,
        professional: professional,
        service: stale_service,
        start_at: start_at
      )

      expect(result).to be_persisted
      expect(result.end_at).to eq(start_at + 45.minutes)
    end

    it "reloads the service under a row lock before deriving end_at" do
      statements = sql_statements { schedule }
      service_reads = statements.grep(/FROM "services"/)
      appointment_write = statements.index { |sql| sql.start_with?("INSERT INTO \"appointments\"") }

      expect(service_reads.first).to match(/FOR UPDATE/i)
      expect(appointment_write).to be > 0
    end

    it "takes the row lock before inserting the appointment" do
      statements = sql_statements { schedule }
      lock_index = statements.index { |sql| sql.match?(/FROM "services".*FOR UPDATE/i) }
      insert_index = statements.index { |sql| sql.start_with?("INSERT INTO \"appointments\"") }

      expect(lock_index).to be < insert_index
    end

    it "returns a domain error when the service row disappears before the lock is taken" do
      # A concurrent admin destroy commits between the initial read and the row lock, so the
      # locking reload raises RecordNotFound instead of inserting against a missing service.
      allow(service).to receive(:reload).and_raise(ActiveRecord::RecordNotFound)

      result = schedule

      expect(result).not_to be_persisted
      expect(result.errors[:base]).to include("serviço não está mais disponível")
    end

    it "does not persist an appointment when the service row disappears" do
      allow(service).to receive(:reload).and_raise(ActiveRecord::RecordNotFound)

      expect { schedule }.not_to change(Appointment, :count)
    end

    it "derives end_at instead of trusting a client-supplied value" do
      result = described_class.call(
        client: client,
        professional: professional,
        service: service,
        start_at: start_at,
        end_at: start_at + 2.hours
      )

      expect(result).to be_persisted
      expect(result.end_at).to eq(start_at + service.duration_minutes.minutes)
    end

    it "normalizes an ISO 8601 start time before validating and persisting it" do
      start_time = start_at.iso8601

      result = schedule(start_time: start_time)

      expect(result).to be_persisted
      expect(result.start_at).to eq(start_at)
      expect(result.end_at).to eq(start_at + service.duration_minutes.minutes)
    end

    it "rejects an unparseable start time without raising" do
      expect { schedule(start_time: "not-a-time") }.not_to raise_error

      result = schedule(start_time: "not-a-time")

      expect(result).not_to be_persisted
      expect(result.errors[:base]).to include("horário é inválido")
    end

    it "rejects unsupported start time types without raising" do
      [ 123, true, [], {} ].each do |start_time|
        expect { schedule(start_time: start_time) }.not_to raise_error

        result = schedule(start_time: start_time)

        expect(result).not_to be_persisted
        expect(result.errors[:base]).to include("horário é inválido")
      end
    end

    it "rejects an out-of-range start time without raising" do
      expect { schedule(start_time: "2026-99-99T10:00:00-03:00") }.not_to raise_error

      result = schedule(start_time: "2026-99-99T10:00:00-03:00")

      expect(result).not_to be_persisted
      expect(result.errors[:base]).to include("horário é inválido")
    end

    it "rejects a non-positive service duration" do
      service.duration_minutes = 0
      service.save(validate: false)

      result = schedule

      expect(result).not_to be_persisted
      expect(result.errors[:base]).to include("duração do serviço é inválida")
    end

    it "rejects a slot occupied by another appointment" do
      occupy!(start_at)
      result = schedule

      expect(result).not_to be_persisted
      expect(result.errors[:base]).to include("profissional já possui um agendamento nesse horário")
    end

    it "returns a domain error instead of raising when the service is missing" do
      result = described_class.call(
        client: client,
        professional: professional,
        service: nil,
        start_at: start_at
      )

      expect(result).not_to be_persisted
      expect(result.errors[:base]).to include("serviço é obrigatório")
    end

    it "returns a domain error instead of raising when the start time is missing" do
      result = schedule(start_time: nil)

      expect(result).not_to be_persisted
      expect(result.errors[:base]).to include("horário é obrigatório")
    end
  end
end
