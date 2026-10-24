require "rails_helper"

# A unidade é gravada no agendamento, e não deduzida do link.
#
# O link de confirmação chega por e-mail e pode ser aberto depois de o cliente
# trocar de unidade no site, ou num dispositivo com outra sessão. Se a unidade
# fosse lida do link, o agendamento apareceria na unidade errada — ou em
# nenhuma. No appointment, a unidade é fato: foi nela que o horário foi
# reservado.
RSpec.describe "unidade no agendamento" do
  let!(:barbearia) { Barbershop.create!(name: "Barbearia Agend", slug: "agend") }
  let!(:outra_barbershop) { Barbershop.create!(name: "Outra Agend", slug: "outra-agend") }

  let!(:centro) do
    within_tenant(barbearia) do
      BarbershopUnit.create!(barbershop: barbearia, name: "Centro", slug: "centro")
    end
  end
  let!(:jardim) do
    within_tenant(barbearia) do
      BarbershopUnit.create!(barbershop: barbearia, name: "Jardim", slug: "jardim")
    end
  end

  # `let` e não `before` porque a criação depende de `barbearia`, que também é
  # `let`: a ordem de resolução do RSpec cuida disso. O contexto de tenant é
  # ligado dentro do próprio bloco, porque sem `Current` a validação de
  # TenantScoped recusa cliente e serviço.
  let(:servico) do
    within_tenant(barbearia) { Service.create!(name: "Corte Agend #{SecureRandom.hex(2)}", duration_minutes: 30) }
  end

  let(:cliente) do
    within_tenant(barbearia) { Client.create!(name: "Cliente Agend #{SecureRandom.hex(2)}", phone: "1198#{SecureRandom.random_number(10**8)}") }
  end

  def profissional_da(unidade, nome)
    within_tenant(barbearia) { Professional.create!(name: "#{nome} #{SecureRandom.hex(2)}", barbershop_unit: unidade) }
  end

  def profissional_geral(nome)
    within_tenant(barbearia) { Professional.create!(name: "#{nome} #{SecureRandom.hex(2)}") }
  end

  # O agendamento é criado dentro de `within_tenant`: sem isso a validação de
  # TenantScoped recusa todas as associações como "de outra barbearia" — é a
  # fronteira funcionando com Current vazio, não um bug do agendamento.
  def novo_appointment(unidade:, profissional:, hora: 14, dias: 3)
    within_tenant(barbearia) do
      slot = dias.days.from_now.change(hour: hora, min: 0, sec: 0)
      Appointment.create!(
        professional: profissional, client: cliente, service: servico,
        barbershop_unit: unidade,
        start_at: slot, end_at: slot + 30.minutes
      )
    end
  end

  it "grava a unidade do agendamento" do
    profissional = profissional_da(centro, "Do Centro")

    appointment = novo_appointment(unidade: centro, profissional: profissional)

    expect(appointment.barbershop_unit).to eq(centro)
  end

  it "grava a unidade mesmo quando o profissional atende em todas" do
    # Profissional sem unidade atende em qualquer uma, então é a unidade
    # escolhida que diz onde o horário foi reservado — não o cadastro dele.
    profissional = profissional_geral("Geral")

    appointment = novo_appointment(unidade: jardim, profissional: profissional)

    expect(appointment.barbershop_unit).to eq(jardim)
  end

  it "recusa agendamento sem unidade" do
    profissional = profissional_geral("Sem Unidade")
    slot = 3.days.from_now.change(hour: 15, min: 0, sec: 0)

    candidato = within_tenant(barbearia) do
      Appointment.new(professional: profissional, client: cliente, service: servico,
                      start_at: slot, end_at: slot + 30.minutes)
    end

    expect(candidato).to be_invalid
    expect(candidato.errors[:barbershop_unit]).to be_present
  end

  it "recusa agendamento em unidade de outra barbearia" do
    unidade_alheia = within_tenant(outra_barbershop) do
      BarbershopUnit.create!(barbershop: outra_barbershop, name: "Alheia", slug: "alheia")
    end
    profissional = profissional_geral("Fronteira")
    slot = 4.days.from_now.change(hour: 16, min: 0, sec: 0)

    candidato = within_tenant(barbearia) do
      Appointment.new(professional: profissional, client: cliente, service: servico,
                      barbershop_unit: unidade_alheia,
                      start_at: slot, end_at: slot + 30.minutes)
    end

    expect(candidato).to be_invalid
    expect(candidato.errors[:barbershop_unit]).to be_present
  end

  it "a agenda da unidade não mostra o agendamento da outra" do
    do_centro = novo_appointment(unidade: centro, profissional: profissional_da(centro, "Prof Centro"))
    do_jardim = novo_appointment(unidade: jardim, profissional: profissional_da(jardim, "Prof Jardim"), hora: 15)

    # As leituras ficam dentro de `within_tenant`: o helper restaura Current ao
    # sair, e `Appointment.for_unit` herda o `default_scope`, que lê Current.
    lista = within_tenant(barbearia) do
      { centro: Appointment.for_unit(centro).to_a, jardim: Appointment.for_unit(jardim).to_a }
    end

    expect(lista[:centro]).to contain_exactly(do_centro)
    expect(lista[:centro]).not_to include(do_jardim)
    expect(lista[:jardim]).to contain_exactly(do_jardim)
  end
end
