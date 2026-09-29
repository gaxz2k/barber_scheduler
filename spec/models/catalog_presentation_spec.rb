require "rails_helper"

# A vitrine precisa mostrar preço e especialidade, e os dois precisam ter um
# comportamento explícito quando o dado não existe — a maioria dos serviços
# cadastrados hoje não tem preço, e "R$ " sozinho na tela é pior do que nada.
#
# O describe externo é uma string porque cobre dois models; cada `describe`
# interno nomeia o seu.
# rubocop:disable RSpec/DescribeClass
RSpec.describe "apresentação de catálogo" do
  describe Service do
    it "formata o preço em reais quando existe" do
      service = build_service(price_cents: 8000)

      expect(service.price_label).to eq("R$ 80,00")
    end

    it "formata preço acima de mil reais sem perder a casa dos milhares" do
      service = build_service(price_cents: 220_000)

      expect(service.price_label).to eq("R$ 2.200,00")
    end

    it "devolve nil sem preço, para a view esconder o campo" do
      service = build_service(price_cents: nil)

      # Nil, e não string vazia: a view decide se mostra o espaço do preço, e
      # "R$ " ocupa a linha sem dizer nada.
      expect(service.price_label).to be_nil
    end

    it "devolve nil para preço zero" do
      expect(build_service(price_cents: 0).price_label).to be_nil
    end
  end

  # `described_class` aqui é a string do describe externo, então o model vem
  # nomeado — usar `described_class` devolveria o texto, não a classe.
  describe Professional do
    it "devolve a especialidade quando existe" do
      professional = described_class.create!(name: "Especialista", specialty: "Degradê e navalha")

      expect(professional.specialty_label).to eq("Degradê e navalha")
    end

    it "devolve nil sem especialidade, para a view esconder o campo" do
      professional = described_class.create!(name: "Sem Especialidade")

      expect(professional.specialty_label).to be_nil
    end
  end

  def build_service(price_cents:)
    within_tenant { Service.new(name: "Servico Teste #{SecureRandom.hex(2)}", duration_minutes: 30, price_cents: price_cents) }
  end
end
# rubocop:enable RSpec/DescribeClass
