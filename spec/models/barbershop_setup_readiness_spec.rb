require "rails_helper"

# Uma barbearia não está pronta enquanto não tem o mínimo para atender.
#
# "Pronta" é o que o cliente vê: sem serviço não há o que agendar, sem
# profissional não há quem atenda, sem horário de funcionamento a agenda fica
# vazia, e sem unidade não há onde o cliente escolha ir. Um painel que só
# avisa depois é um painel que o usuário ignora até a primeira reclamação.
#
# O que este spec NÃO é: um teste de "a página mostra um aviso". É o teste de
# que a barbershop **responde** sobre a própria prontidão, porque é esse
# método que a interface vai consumir.
RSpec.describe Barbershop, "prontidão para atendimento" do
  let!(:barbearia) { described_class.create!(name: "Barbearia Pronta", slug: "pronta-#{SecureRandom.hex(4)}") }
  # A unidade CRUA, e não `test_unit_for`: o helper define um expediente de
  # 08:00 às 22:00 para os specs que precisam de agenda, e usá-lo aqui
  # deixaria a barbearia pronta antes de o teste pedir horário — o exemplo
  # passaria sem exercitar a regra.
  let(:unidade) { within_tenant(barbearia) { barbearia.unidades.order(:id).first } }
  let(:data) { Date.current + 1 }

  def com_servico
    within_tenant(barbearia) { Service.create!(name: "Corte #{SecureRandom.hex(2)}", duration_minutes: 30) }
  end

  def com_profissional
    within_tenant(barbearia) { Professional.create!(name: "Prof #{SecureRandom.hex(2)}", barbershop_unit: unidade) }
  end

  def com_horario
    dentro_tenant do
      unidade.update!(opening_hours: (1..6).to_h { |d| [ d.to_s, { "open" => "08:00", "close" => "19:00" } ] })
    end
  end

  it "não está pronta sem nada cadastrado" do
    dentro_tenant { expect(barbearia).not_to be_setup_complete }
  end

  it "aponta o que falta" do
    dentro_tenant do
      faltando = barbearia.missing_setup

      expect(faltando).to include(:servicos, :profissionais, :horarios)
    end
  end

  it "não está pronta sem serviço" do
    com_profissional
    com_horario

    dentro_tenant { expect(barbearia).not_to be_setup_complete }
  end

  it "não está pronta sem profissional" do
    com_servico
    com_horario

    dentro_tenant { expect(barbearia).not_to be_setup_complete }
  end

  it "não está pronta sem horário de funcionamento" do
    com_servico
    com_profissional

    dentro_tenant { expect(barbearia).not_to be_setup_complete }
  end

  it "está pronta com serviço, profissional e horário" do
    com_servico
    com_profissional
    com_horario

    dentro_tenant { expect(barbearia).to be_setup_complete }
  end

  it "a unidade principal já conta como unidade" do
    dentro_tenant { expect(barbearia.unidades.count).to be >= 1 }
  end

  it "não conta serviço de outra barbearia" do
    outra = described_class.create!(name: "Outra Pronta", slug: "outra-#{SecureRandom.hex(4)}")
    within_tenant(outra) { Service.create!(name: "Corte Alheio", duration_minutes: 30) }
    com_profissional
    com_horario

    dentro_tenant { expect(barbearia.missing_setup).to include(:servicos) }
  end

  it "não conta profissional de outra barbearia" do
    outra = described_class.create!(name: "Outra Pronta", slug: "outra-#{SecureRandom.hex(4)}")
    within_tenant(outra) { Professional.create!(name: "Prof Alheio") }
    com_servico
    com_horario

    dentro_tenant { expect(barbearia.missing_setup).to include(:profissionais) }
  end

  it "uma unidade sem horário não impede a barbearia de atender" do
    com_servico
    com_profissional
    com_horario
    # Uma segunda unidade, criada sem expediente. Quem escolher a Jardim vê
    # agenda vazia — a resposta certa para uma loja que não atende — e a
    # barbearia continua apta a atender na unidade que tem horário.
    within_tenant(barbearia) do
      BarbershopUnit.create!(barbershop: barbearia, name: "Jardim", slug: "jardim-#{SecureRandom.hex(4)}")
    end

    dentro_tenant { expect(barbearia).to be_setup_complete }
  end

  it "sem horário em nenhuma unidade a barbearia não está pronta" do
    com_servico
    com_profissional
    within_tenant(barbearia) do
      BarbershopUnit.create!(barbershop: barbearia, name: "Jardim", slug: "jardim-#{SecureRandom.hex(4)}")
    end

    dentro_tenant { expect(barbearia.missing_setup).to include(:horarios) }
  end

  def dentro_tenant(&bloco)
    within_tenant(barbearia, &bloco)
  end
end
