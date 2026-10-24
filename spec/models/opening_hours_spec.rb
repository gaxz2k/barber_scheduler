require "rails_helper"

# O horário de funcionamento decide quais slots existem.
#
# Sem ele, o cálculo varre o dia inteiro e oferece 03:00 para alguém que
# cadastrou "9h às 19h". O horário é o que a barbearia prometeu ao cliente, e
# um horário oferecido que a loja não atende vira cliente que veio e não
# passou.
#
# O último agendamento tem que CABER inteiro antes do fechamento: com serviço
# de 30 minutos e fechamento às 19h, o último é 18:30. Um 19:00 que acabaria
# 19:30 é um horário que a loja não pode cumprir.
RSpec.describe "horário de funcionamento", type: :model do
  let!(:barbearia) { Barbershop.create!(name: "Barbearia Horário", slug: "horario-#{SecureRandom.hex(4)}") }
  let(:unidade) { barbearia.unidades.order(:id).first }
  let(:servico) { within_tenant(barbearia) { Service.create!(name: "Corte", duration_minutes: 30) } }
  let(:profissional) { within_tenant(barbearia) { Professional.create!(name: "Prof #{SecureRandom.hex(2)}", barbershop_unit: unidade) } }
  # Uma quarta-feira, para o teste não depender de dia de fim de semana.
  let(:data) { Date.current.next_occurring(:wednesday) + 1 }

  def slots_para(date = data, servico_local = servico)
    within_tenant(barbearia) do
      AvailableSlots::Calculator.new(
        professional: profissional, date: date, service: servico_local, barbershop_unit: unidade
      ).call
    end
  end

  def definir_horario(abre, fecha, dia: data.wday)
    within_tenant(barbearia) do
      unidade.update!(opening_hours: { dia.to_s => { "open" => abre, "close" => fecha } })
    end
  end

  def hora(slot) = slot.in_time_zone.strftime("%H:%M")

  it "oferece slots dentro do horário cadastrado" do
    definir_horario("08:00", "19:00")

    horas = slots_para.map { |s| hora(s) }
    expect(horas.first).to eq("08:00")
    expect(horas.last).to eq("18:30")
    expect(horas).to include("12:00")
  end

  it "não oferece nada fora do horário" do
    definir_horario("08:00", "19:00")

    todos = slots_para.map { |s| hora(s) }
    expect(todos).to all(be_between("08:00", "18:30"))
  end

  it "o último agendamento cabe inteiro antes de fechar" do
    definir_horario("08:00", "19:00")

    expect(horas(slots_para).last).to eq("18:30")
  end

  it "não oferece nada quando não há horário cadastrado" do
    # Barbearia sem horário mostra agenda vazia, e não um palpite. Deduzir
    # horário é o mesmo erro de deduzir unidade: o cliente marcaria algo que a
    # loja não confirmou.
    expect(slots_para).to be_empty
  end

  it "sem horário não oferece nada mesmo com serviço longo" do
    longo = within_tenant(barbearia) { Service.create!(name: "Cabelo", duration_minutes: 120) }

    expect(slots_para(data, longo)).to be_empty
  end

  it "respeita o serviço: o que não cabe antes de fechar não entra" do
    definir_horario("09:00", "11:00")

    # Com 120 minutos e janela 09:00-11:00, só o 09:00 cabe: ele termina às
    # 11:00, exatamente no fechamento. O 09:30 terminaria 11:30.
    longo = within_tenant(barbearia) { Service.create!(name: "Cabelo", duration_minutes: 120) }
    expect(horas(slots_para(data, longo))).to eq(%w[09:00])
  end

  it "usa o horário da unidade, e não o padrão da barbearia" do
    within_tenant(barbearia) { unidade.update!(opening_hours: { data.wday.to_s => { "open" => "08:00", "close" => "19:00" } }) }

    expect(horas(slots_para)).to include("08:00")
  end

  describe "dias sem expediente" do
    it "não oferece nada no dia que não abre" do
      # O dia alvo fica FORA de propósito: abrir `data.wday` seria o caminho
      # feliz, e o teste passaria sem exercitar a recusa. Os outros dias da
      # semana abrem, para que a agenda vazia venha da ausência do dia e não
      # de uma configuração sem nenhum dia.
      abertos = (0..6).to_a - [ data.wday ]
      todos = abertos.to_h { |dia| [ dia.to_s, { "open" => "08:00", "close" => "19:00" } ] }
      within_tenant(barbearia) { unidade.update!(opening_hours: todos) }

      expect(slots_para).to be_empty
    end

    it "não oferece nada no domingo" do
      domingo = Date.current.next_occurring(:sunday)
      within_tenant(barbearia) do
        # A chave do domingo é OMITIDA, e não valendo nil: no jsonb um null
        # volta como a string vazia depois de persistir, e a diferença entre
        # "não cadastrado" e "cadastrado vazio" se perde na viagem.
        todos_os_dias = (1..6).each_with_object({}) do |dia, acc|
          acc[dia.to_s] = { "open" => "08:00", "close" => "19:00" }
        end
        unidade.update!(opening_hours: todos_os_dias)
      end

      expect(slots_para(domingo)).to be_empty
    end
  end

  def horas(slots) = slots.map { |s| hora(s) }
end
