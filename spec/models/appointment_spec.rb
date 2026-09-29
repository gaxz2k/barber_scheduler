require 'rails_helper'
require 'securerandom'

RSpec.describe Appointment, type: :model do
  describe "attributes" do
    let(:professional) { Professional.create!(name: "Profissional Teste") }
    let(:client) { Client.create!(name: "Cliente Teste", phone: "123") }
    let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
    let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

    it "belongs to a professional" do
      appointment = described_class.create!(
        professional: professional,
        client: client,
        service: service,
        barbershop_unit: test_unit_for(test_barbershop),
        start_at: start_at,
        end_at: start_at + Scheduling::SLOT_DURATION
      )

      expect(appointment.professional).to eq(professional)
    end

    it "generates the confirmation token only when the appointment is persisted" do
      appointment = described_class.new(
        professional: professional,
        client: client,
        service: service,
        barbershop_unit: test_unit_for(test_barbershop),
        start_at: start_at,
        end_at: start_at + Scheduling::SLOT_DURATION
      )

      expect(appointment.confirmation_token).to be_nil

      appointment.save!

      expect(appointment.confirmation_token).to be_present
      expect(appointment.confirmation_token.length).to eq(32)
    end

    it "sets an expiration for the confirmation token" do
      appointment = described_class.create!(
        professional: professional,
        client: client,
        service: service,
        barbershop_unit: test_unit_for(test_barbershop),
        start_at: start_at,
        end_at: start_at + Scheduling::SLOT_DURATION
      )

      expect(appointment.confirmation_expires_at).to be_present
    end

    it "revokes the confirmation when the appointment becomes terminal" do
      appointment = described_class.create!(
        professional: professional,
        client: client,
        service: service,
        barbershop_unit: test_unit_for(test_barbershop),
        start_at: start_at,
        end_at: start_at + Scheduling::SLOT_DURATION,
        status: :canceled
      )

      expect(appointment.confirmation_accessible?).to be(false)
    end
  end

  describe "agenda" do
    let(:professional) { Professional.create!(name: "Profissional Agenda") }
    let(:client) { Client.create!(name: "Cliente Agenda", phone: "11987654321") }
    let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
    let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

    def build_appointment(**attributes)
      Appointment.new(
        {
          client: client,
          professional: professional,
          service: service,
          # A unidade é obrigatória, e um agendamento sem ela não existe. Vai
          # no helper e não em cada exemplo: o que estes exemplos provam é
          # duração, grade e status, e a unidade é cenário, não asserção.
          barbershop_unit: test_unit_for(test_barbershop),
          start_at: start_at,
          end_at: start_at + service.duration_minutes.minutes
        }.merge(attributes)
      )
    end

    def create_appointment(**attributes)
      build_appointment(**attributes).tap(&:save!)
    end

    it "rejects an end time before the start time" do
      appointment = build_appointment(end_at: start_at - 1.minute)

      expect(appointment).not_to be_valid
      expect(appointment.errors[:end_at]).to include("deve ser depois do início")
    end

    it "rejects a start time outside the slot grid" do
      appointment = build_appointment(start_at: start_at + 5.minutes, end_at: start_at + 35.minutes)

      expect(appointment).not_to be_valid
      expect(appointment.errors[:start_at]).to include("não está alinhado à grade de horários")
    end

    it "rejects an end time that does not match the service duration" do
      appointment = build_appointment(end_at: start_at + 5.minutes)

      expect(appointment).not_to be_valid
      expect(appointment.errors[:end_at]).to include("deve corresponder à duração do serviço")
    end

    it "ignores canceled appointments when checking conflicts" do
      create_appointment(status: :canceled)

      expect(create_appointment).to be_persisted
    end

    it "ignores completed appointments when checking conflicts" do
      create_appointment(status: :completed)

      expect(create_appointment).to be_persisted
    end

    it "keeps active appointments with the same interval for different professionals" do
      other_professional = Professional.create!(name: "Profissional Outro")
      first = create_appointment

      second = create_appointment(professional: other_professional)

      expect(first).to be_persisted
      expect(second).to be_persisted
    end

    it "allows a canceled appointment to be edited without a false conflict" do
      canceled = create_appointment(status: :canceled)
      canceled.start_at = start_at + 1.hour
      canceled.end_at = canceled.start_at + service.duration_minutes.minutes

      expect(canceled).to be_valid
    end
  end

  describe "start_at in the past" do
    subject(:appointment) do
      described_class.new(
        professional: professional,
        client: client,
        service: service,
        start_at: start_at,
        end_at: start_at + Scheduling::SLOT_DURATION
      )
    end

    let(:professional) { Professional.create!(name: "Profissional Passado") }
    let(:client) { Client.create!(name: "Cliente Passado", phone: "11987650001") }
    let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
    let(:start_at) { 1.day.ago.change(hour: 10, min: 0) }


    it "is invalid" do
      expect(appointment).not_to be_valid
    end

    it "has an error on start_at" do
      appointment.valid?

      expect(appointment.errors[:start_at]).to include("não pode ser no passado")
    end
  end

  describe "overlapping appointment for the same professional" do
    subject(:overlapping) do
      described_class.new(
        professional: professional,
        client: client,
        service: service,
        start_at: start_at + 15.minutes,
        end_at: start_at + 45.minutes
      )
    end

    let(:professional) { Professional.create!(name: "Profissional Sobreposto") }
    let(:client) { Client.create!(name: "Cliente Sobreposto", phone: "11987650002") }
    let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
    let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }


    before do
      described_class.create!(
        professional: professional,
        client: client,
        service: service,
        barbershop_unit: test_unit_for(test_barbershop),
        start_at: start_at,
        end_at: start_at + Scheduling::SLOT_DURATION
      )
    end

    it "is invalid" do
      expect(overlapping).not_to be_valid
    end

    it "has an error about the professional's schedule" do
      overlapping.valid?

      expect(overlapping.errors[:base]).to include("profissional já possui um agendamento nesse horário")
    end
  end

  describe "database schedule constraints" do
    let(:professional) { Professional.create!(name: "Profissional Banco") }
    let(:client) { Client.create!(name: "Cliente Banco", phone: "11987650004") }
    let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
    let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

    it "rejects overlapping active rows even when model validations are bypassed" do
      described_class.create!(
        client: client,
        professional: professional,
        service: service,
        barbershop_unit: test_unit_for(test_barbershop),
        start_at: start_at,
        end_at: start_at + Scheduling::SLOT_DURATION
      )

      expect do
        described_class.insert_all!([
          {
            client_id: client.id,
            professional_id: professional.id,
            service_id: service.id,
            # A unidade vai no insert porque a coluna é NOT NULL: sem ela a
            # inserção falharia por violação de coluna, e o exemplo passaria
            # pelo motivo errado — ele existe para provar a restrição de
            # sobreposição, não a obrigatoriedade da unidade.
            barbershop_unit_id: test_unit_for(test_barbershop).id,
            confirmation_token: SecureRandom.hex(16),
            confirmation_expires_at: 48.hours.from_now,
            start_at: start_at,
            end_at: start_at + Scheduling::SLOT_DURATION,
            status: described_class.statuses[:pending],
            created_at: Time.current,
            updated_at: Time.current
          }
        ])
      end.to raise_error(ActiveRecord::ExclusionViolation)
    end
  end

  describe "canceling a completed appointment" do
    subject(:appointment) do
      described_class.create!(
        professional: professional,
        client: client,
        service: service,
        barbershop_unit: test_unit_for(test_barbershop),
        start_at: start_at,
        end_at: start_at + Scheduling::SLOT_DURATION,
        status: :completed
      )
    end

    let(:professional) { Professional.create!(name: "Profissional Concluído") }
    let(:client) { Client.create!(name: "Cliente Concluído", phone: "11987650003") }
    let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
    let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }


    it "raises an error" do
      expect { appointment.cancel! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "keeps the status as completed" do
      suppress(ActiveRecord::RecordInvalid) { appointment.cancel! }

      expect(appointment.reload.status).to eq("completed")
    end
  end

  describe "#status_label" do
    let(:professional) { Professional.create!(name: "Profissional") }
    let(:client) { Client.create!(name: "Cliente", phone: "11987650010") }
    let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
    let(:appointment) do
      described_class.create!(professional: professional, client: client, service: service,
      barbershop_unit: test_unit_for(test_barbershop),
                              start_at: 1.day.from_now.change(hour: 10, min: 0),
                              end_at: 1.day.from_now.change(hour: 10, min: 30))
    end

    # `status` é uma String e String#humanize não passa pelo I18n, então o
    # rótulo saía "Pending" numa tela toda em português. Um cliente brasileiro
    # lendo "Pending" numa confirmação parece tela quebrada.
    it "traduz o status pendente" do
      expect(appointment.status_label).to eq("Aguardando")
    end

    it "traduz os demais status" do
      appointment.confirm!
      expect(appointment.status_label).to eq("Confirmado")

      appointment.cancel!
      expect(appointment.status_label).to eq("Cancelado")
    end

    it "cai no humanize quando o status nao tem traducao" do
      # O enum não aceita valor fora da lista, então o fallback é exercitado
      # removendo a tradução em vez de inventar um status.
      I18n.backend.reload!
      key = "activerecord.attributes.appointment.statuses.#{appointment.status}"
      I18n.backend.store_translations(:'pt-BR', key => {})

      expect(appointment.status_label).to eq("Aguardando".humanize)
    end
  end
end
