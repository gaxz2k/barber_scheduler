require 'rails_helper'

RSpec.describe AvailableSlots::Calculator, type: :service do
  let(:professional) { Professional.create!(name: "Profissional Teste") }
  let(:client) { Client.create!(name: "Cliente Teste", phone: "11987654321") }
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:date) { Date.current + 1 }

  def calculate
    described_class.new(professional: professional, date: date, service: service, barbershop_unit: test_unit_for(test_barbershop)).call
  end

  def occupy!(start_time, status: :pending)
    create_test_appointment!(
      client: client,
      professional: professional,
      service: service,
      start_at: start_time,
      end_at: start_time + Scheduling::SLOT_DURATION,
      status: status
    )
  end

  describe "#call" do
    it "returns slots at the fixed half-hour grid" do
      expect(calculate).to include(
        date.in_time_zone.change(hour: 9, min: 0),
        date.in_time_zone.change(hour: 9, min: 30)
      )
    end

    it "returns slots in chronological order" do
      expect(calculate).to eq(calculate.sort)
    end

    it "does not return slots that have already passed today" do
      today = Date.current
      current_time = today.in_time_zone.change(hour: 12, min: 0)

      allow(Time).to receive(:current).and_return(current_time)

      slots = described_class.new(
        professional: professional,
        date: today,
        service: service,
        barbershop_unit: test_unit_for(test_barbershop)
      ).call

      # Ancorado no "agora" e não em 12:00: a suite roda a qualquer hora do
      # dia, e um horario fixo passa a tarde e quebra de manha.
      #
      # Passado: a meia hora ANTERIOR a agora, que com certeza ja passou.
      # Futuro: a proxima meia hora, que ainda esta dentro do expediente de
      # 08:00 as 22:00 que o helper define. O instante exato de agora nao e
      # usado de proposito: o filtro e `>=`, entao ele aparece, e afirmar o
      # contrario mediria o filtro em vez do que interessa.
      agora = Time.current
      passada = agora - 30.minutes
      futura = agora.change(min: ((agora.min / 30) * 30) + 30, sec: 0)

      expect(slots).not_to include(passada)
      expect(slots).to include(futura)
    end

    it "returns an empty list for a blank date" do
      expect(described_class.new(professional: professional, date: nil, service: service).call).to eq([])
    end

    it "returns an empty list for a date without a time zone" do
      expect(described_class.new(professional: professional, date: "invalid", service: service).call).to eq([])
    end

    it "returns an empty list for a blank professional" do
      expect(described_class.new(professional: nil, date: date, service: service).call).to eq([])
    end


    it "excludes a slot occupied by an appointment" do
      occupied_at = date.in_time_zone.change(hour: 10, min: 0)
      occupy!(occupied_at)

      expect(calculate).not_to include(occupied_at)
    end

    it "keeps adjacent slots available" do
      occupied_at = date.in_time_zone.change(hour: 10, min: 0)
      occupy!(occupied_at)

      expect(calculate).to include(occupied_at + Scheduling::SLOT_DURATION)
    end

    it "includes a slot occupied only by a canceled appointment" do
      occupied_at = date.in_time_zone.change(hour: 10, min: 0)
      occupy!(occupied_at, status: :canceled)

      expect(calculate).to include(occupied_at)
    end

    it "includes a slot occupied only by a completed appointment" do
      occupied_at = date.in_time_zone.change(hour: 10, min: 0)
      occupy!(occupied_at, status: :completed)

      expect(calculate).to include(occupied_at)
    end

    it "does not return a slot that would run past the end of the day" do
      expect(calculate).to all(be < date.in_time_zone.end_of_day)
    end

    it "does not return a slot whose service interval would cross the next day" do
      service.update!(duration_minutes: 90)

      expect(calculate).to all(satisfy { |slot| slot + 90.minutes <= date.in_time_zone.end_of_day })
    end
  end
end
