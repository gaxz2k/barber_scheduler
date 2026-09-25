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
