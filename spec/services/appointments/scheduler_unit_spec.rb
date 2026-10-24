require "rails_helper"

# Agendar exige uma unidade escolhida, sempre.
#
# A unidade é onde o cliente vai estar. Um agendamento sem ela é um agendamento
# que o sistema não sabe onde colocar, e deduzir uma — a do profissional, ou a
# principal da barbearia — converte "não informado" em "principal" sem ninguém
# pedir. O defeito aparece tarde e longe: o cliente aparece numa loja que não
# conhece, e ninguém sabe onde o erro entrou.
RSpec.describe Appointments::Scheduler, "unidade obrigatória" do
  let!(:barbearia) { Barbershop.create!(name: "Barbearia Agenda", slug: "agenda-#{SecureRandom.hex(4)}") }
  let(:unidade) { barbearia.unidades.order(:id).first }
  let(:inicio) { 3.days.from_now.change(hour: 14, min: 0) }

  let(:servico) do
    within_tenant(barbearia) { Service.create!(name: "Corte #{SecureRandom.hex(2)}", duration_minutes: 30) }
  end

  let(:cliente) do
    within_tenant(barbearia) do
      Client.create!(name: "Cliente #{SecureRandom.hex(2)}", phone: "1198#{SecureRandom.random_number(10**8)}")
    end
  end

  let(:com_unidade) do
    within_tenant(barbearia) { Professional.create!(name: "Prof #{SecureRandom.hex(2)}", barbershop_unit: unidade) }
  end

  let(:sem_unidade) do
    within_tenant(barbearia) { Professional.create!(name: "Prof #{SecureRandom.hex(2)}") }
  end

  def agendar(profissional, **extra)
    within_tenant(barbearia) do
      described_class.call(
        client: cliente, professional: profissional, service: servico, start_at: inicio, **extra
      )
    end
  end

  it "recusa agendar sem escolher unidade" do
    # `ArgumentError` e não um Appointment inválido: a assinatura exige a
    # unidade, então a chamada falha antes de chegar ao banco. Levantar é o
    # que impede a escrita — um Appointment inválido ainda poderia ser
    # gravado por quem chamasse com `save(validate: false)`.
    expect { agendar(sem_unidade) }.to raise_error(ArgumentError, /barbershop_unit/)
  end

  it "não deduz a unidade do profissional" do
    expect { agendar(com_unidade) }.to raise_error(ArgumentError, /barbershop_unit/)
  end

  it "não grava nada quando a unidade falta" do
    # O `raise` já garante que nada foi escrito — a falha acontece no
    # construtor, antes de `call` montar o Appointment. A contagem confirma
    # que a exceção não deixou registro pela metade.
    expect { agendar(sem_unidade) }.to raise_error(ArgumentError)

    expect(within_tenant(barbearia) { Appointment.count }).to eq(0)
  end

  it "grava a unidade escolhida" do
    resultado = agendar(sem_unidade, barbershop_unit: unidade)

    expect(resultado).to be_persisted
    expect(resultado.barbershop_unit_id).to eq(unidade.id)
  end

  it "a unidade escolhida precisa ser da mesma barbearia" do
    outra = Barbershop.create!(name: "Outra Agenda", slug: "outra-#{SecureRandom.hex(4)}")
    alheia = within_tenant(outra) { outra.unidades.order(:id).first }

    resultado = agendar(sem_unidade, barbershop_unit: alheia)

    expect(resultado).not_to be_persisted
  end
end
