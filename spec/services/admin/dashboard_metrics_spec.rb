require "rails_helper"

# `Admin::DashboardMetrics` é o service que calcula tudo o que a home admin
# mostra em métricas (ver `diagnostics-dashboard-design`): o servidor decide
# tom e texto, a view só pinta. Estes exemplos cobrem o cálculo isolado de
# cada indicador, os limiares de tom e o isolamento entre barbearias.
#
RSpec.describe Admin::DashboardMetrics, type: :model do
  let(:barbershop) { test_barbershop }
  let(:unit) { test_unit_for(barbershop) }

  def criar_agendamento!(client:, professional:, status:, start_at: 1.day.ago)
    service = within_tenant(barbershop) { Service.find_or_create_by!(name: "Corte") { |s| s.duration_minutes = 30 } }

    appointment = within_tenant(barbershop) do
      Appointment.new(
        client: client, professional: professional, service: service,
        barbershop_unit: unit, start_at: start_at, end_at: start_at + 30.minutes,
        status: :pending, confirmation_expires_at: 48.hours.from_now
      )
    end
    appointment.save!(validate: false) # pula validações de grade/disponibilidade: o que importa aqui é status e data
    appointment.status = status
    appointment.save!(validate: false)
    appointment
  end

  describe "#call" do
    context "when there is no data yet" do
      it "total de clientes aparece como neutro" do
        switch_tenant_to(barbershop)

        resultado = described_class.new.call
        indicador = resultado.indicadores.find { |i| i.chave == "total_clientes" }

        expect(indicador.tom).to eq("neutro")
      end

      it "taxa de cancelamento fica sem_dado quando não há agendamento no período" do
        switch_tenant_to(barbershop)

        resultado = described_class.new.call
        indicador = resultado.indicadores.find { |i| i.chave == "taxa_cancelamento" }

        expect(indicador.tom).to eq("sem_dado")
      end

      it "a tabela de clientes por profissional vem vazia sem profissionais" do
        switch_tenant_to(barbershop)

        resultado = described_class.new.call

        expect(resultado.clientes_por_profissional).to eq([])
      end

      it "o veredito não afirma problema quando não há dado" do
        switch_tenant_to(barbershop)

        resultado = described_class.new.call

        expect(resultado.veredito_texto).not_to include("Atenção")
      end
    end

    context "with clients registered" do
      it "conta o total de clientes da barbearia, sem olhar a janela de tempo" do
        switch_tenant_to(barbershop)
        within_tenant(barbershop) { 3.times { |n| Client.create!(name: "Cliente #{n}", phone: "1198765000#{n}") } }

        resultado = described_class.new.call
        indicador = resultado.indicadores.find { |i| i.chave == "total_clientes" }

        expect(indicador.valor).to eq(3)
        expect(indicador.tom).to eq("ok")
      end
    end

    context "when calculating the cancellation rate" do
      it "fica ok quando a proporção de cancelados é baixa" do
        switch_tenant_to(barbershop)
        profissional = within_tenant(barbershop) { Professional.create!(name: "Gustavo") }
        cliente = within_tenant(barbershop) { Client.create!(name: "Ana", phone: "11987650010") }
        9.times { criar_agendamento!(client: cliente, professional: profissional, status: :completed) }
        criar_agendamento!(client: cliente, professional: profissional, status: :canceled) # 1 em 10 = 10%

        resultado = described_class.new.call
        indicador = resultado.indicadores.find { |i| i.chave == "taxa_cancelamento" }

        expect(indicador.tom).to eq("ok")
      end

      it "fica atencao a partir de 15% de cancelamento" do
        switch_tenant_to(barbershop)
        profissional = within_tenant(barbershop) { Professional.create!(name: "Gustavo") }
        cliente = within_tenant(barbershop) { Client.create!(name: "Ana", phone: "11987650011") }
        4.times { criar_agendamento!(client: cliente, professional: profissional, status: :completed) }
        criar_agendamento!(client: cliente, professional: profissional, status: :canceled) # 1 em 5 = 20%

        resultado = described_class.new.call
        indicador = resultado.indicadores.find { |i| i.chave == "taxa_cancelamento" }

        expect(indicador.tom).to eq("atencao")
      end

      it "fica critico a partir de 30% de cancelamento" do
        switch_tenant_to(barbershop)
        profissional = within_tenant(barbershop) { Professional.create!(name: "Gustavo") }
        cliente = within_tenant(barbershop) { Client.create!(name: "Ana", phone: "11987650012") }
        2.times { criar_agendamento!(client: cliente, professional: profissional, status: :completed) }
        2.times { criar_agendamento!(client: cliente, professional: profissional, status: :canceled) } # 2 em 4 = 50%

        resultado = described_class.new.call
        indicador = resultado.indicadores.find { |i| i.chave == "taxa_cancelamento" }

        expect(indicador.tom).to eq("critico")
      end

      it "não vaza o status interno 'canceled' no texto do indicador" do
        switch_tenant_to(barbershop)
        profissional = within_tenant(barbershop) { Professional.create!(name: "Gustavo") }
        cliente = within_tenant(barbershop) { Client.create!(name: "Ana", phone: "11987650013") }
        2.times { criar_agendamento!(client: cliente, professional: profissional, status: :canceled) }

        resultado = described_class.new.call
        indicador = resultado.indicadores.find { |i| i.chave == "taxa_cancelamento" }

        expect(indicador.texto).not_to include("canceled")
        expect(indicador.detalhe).not_to include("canceled")
      end
    end

    context "when citing the verdict's worst indicator" do
      it "afirma o problema concreto quando a taxa de cancelamento é crítica" do
        switch_tenant_to(barbershop)
        profissional = within_tenant(barbershop) { Professional.create!(name: "Gustavo") }
        cliente = within_tenant(barbershop) { Client.create!(name: "Ana", phone: "11987650014") }
        3.times { criar_agendamento!(client: cliente, professional: profissional, status: :canceled) }

        resultado = described_class.new.call

        expect(resultado.veredito_texto).to include("cancelamento")
        expect(resultado.veredito_tom).to eq("critico")
      end
    end

    context "when counting clients per professional" do
      it "conta clientes distintos com agendamento não cancelado no período" do
        switch_tenant_to(barbershop)
        profissional = within_tenant(barbershop) { Professional.create!(name: "Gustavo") }
        cliente_a = within_tenant(barbershop) { Client.create!(name: "Ana", phone: "11987650020") }
        cliente_b = within_tenant(barbershop) { Client.create!(name: "Bia", phone: "11987650021") }
        criar_agendamento!(client: cliente_a, professional: profissional, status: :completed)
        criar_agendamento!(client: cliente_b, professional: profissional, status: :confirmed)

        resultado = described_class.new.call
        linha = resultado.clientes_por_profissional.find { |l| l[:profissional] == profissional }

        expect(linha[:total_clientes]).to eq(2)
      end

      it "não conta cliente cujo único agendamento com o profissional foi cancelado" do
        switch_tenant_to(barbershop)
        profissional = within_tenant(barbershop) { Professional.create!(name: "Gustavo") }
        cliente = within_tenant(barbershop) { Client.create!(name: "Ana", phone: "11987650022") }
        criar_agendamento!(client: cliente, professional: profissional, status: :canceled)

        resultado = described_class.new.call
        linha = resultado.clientes_por_profissional.find { |l| l[:profissional] == profissional }

        expect(linha[:total_clientes]).to eq(0)
      end

      it "lista profissional sem nenhum cliente no período" do
        switch_tenant_to(barbershop)
        profissional = within_tenant(barbershop) { Professional.create!(name: "Sem Clientes") }

        resultado = described_class.new.call
        linha = resultado.clientes_por_profissional.find { |l| l[:profissional] == profissional }

        expect(linha).not_to be_nil
        expect(linha[:total_clientes]).to eq(0)
      end

      it "não considera agendamento fora da janela de #{described_class::JANELA_DIAS} dias" do
        switch_tenant_to(barbershop)
        profissional = within_tenant(barbershop) { Professional.create!(name: "Gustavo") }
        cliente = within_tenant(barbershop) { Client.create!(name: "Ana", phone: "11987650023") }
        criar_agendamento!(client: cliente, professional: profissional, status: :completed, start_at: 90.days.ago)

        resultado = described_class.new.call
        linha = resultado.clientes_por_profissional.find { |l| l[:profissional] == profissional }

        expect(linha[:total_clientes]).to eq(0)
      end
    end

    describe "isolamento entre barbearias" do
      it "clientes de uma barbearia não aparecem no total da outra" do
        outra = other_barbershop
        within_tenant(outra) { Client.create!(name: "Cliente de Outra", phone: "11987650099") }
        switch_tenant_to(barbershop)

        resultado = described_class.new.call
        indicador = resultado.indicadores.find { |i| i.chave == "total_clientes" }

        expect(indicador.valor).to eq(0)
      end

      it "profissionais de uma barbearia não aparecem na tabela da outra" do
        outra = other_barbershop
        within_tenant(outra) { Professional.create!(name: "Profissional de Outra") }
        switch_tenant_to(barbershop)

        resultado = described_class.new.call

        expect(resultado.clientes_por_profissional.map { |l| l[:profissional].name }).not_to include("Profissional de Outra")
      end
    end

    describe "robustez: um indicador que falha não apaga o painel" do
      it "o painel continua com os outros indicadores quando um avaliador explode" do
        switch_tenant_to(barbershop)
        metrics = described_class.new
        allow(metrics).to receive(:indicador_total_clientes).and_raise(StandardError, "boom")

        resultado = metrics.call

        expect(resultado.indicadores.map(&:chave)).not_to include("total_clientes")
        expect(resultado.indicadores.map(&:chave)).to include("taxa_cancelamento", "clientes_com_cancelamento")
      end
    end
  end
end
