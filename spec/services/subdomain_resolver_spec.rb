require "rails_helper"

# Resolução da barbearia pelo subdomínio.
#
# É o que liga o host da requisição ao tenant, e portanto o que faz a aplicação
# voltar a servir dados: sem isto, Current fica vazio e toda consulta escopada
# volta vazia — a página responde 200 e não mostra nada.
RSpec.describe SubdomainResolver do
  # Nomes de host que a aplicação aceita em produção: um subdomínio de cliente
  # mais o domínio base, e os hosts de desenvolvimento.
  let(:app_host) { "barbearia.app" }
  let(:dev_root) { "casa-alfa.localhost" }

  describe ".call" do
    it "acha a barbearia pelo subdomínio" do
      barbershop = Barbershop.create!(name: "Casa Alfa", slug: "casa-alfa")

      achado = described_class.new("casa-alfa.#{app_host}", app_host).call

      expect(achado).to eq(barbershop)
    end

    it "acha a barbearia em localhost de desenvolvimento" do
      barbershop = Barbershop.create!(name: "Casa Alfa", slug: "casa-alfa")

      achado = described_class.new(dev_root, dev_host).call

      expect(achado).to eq(barbershop)
    end

    it "devolve nil para um subdomínio que não existe" do
      Barbershop.create!(name: "Casa Alfa", slug: "casa-alfa")

      achado = described_class.new("inexistente.#{app_host}", app_host).call

      # Nil, e não a barbearia de maior id: um host desconhecido é tratado como
      # inexistente, para não revelar que existe uma plataforma com outras
      # barbearias.
      expect(achado).to be_nil
    end

    it "devolve nil para a raiz sem subdomínio em produção" do
      Barbershop.create!(name: "Casa Alfa", slug: "casa-alfa")

      achado = described_class.new(app_host, app_host).call

      expect(achado).to be_nil
    end

    it "lê um host com acentos sem quebrar" do
      barbershop = Barbershop.create!(name: "Barbearia Ação", slug: "acao")

      # `request.host` chega em ASCII-8BIT, e `parameterize` levanta
      # ArgumentError em vez de transpor quando recebe bytes. O spec do
      # resolver passava antes porque o host vinha do RSpec já em UTF-8 — é o
      # request real que entrega os bytes.
      achado = described_class.new("acao.localhost".dup.force_encoding(Encoding::ASCII_8BIT), "localhost").call

      expect(achado).to eq(barbershop)
    end

    it "ignora a porta ao resolver o subdomínio" do
      barbershop = Barbershop.create!(name: "Casa Alfa", slug: "casa-alfa")

      achado = described_class.new("casa-alfa.#{app_host}:3000", app_host).call

      expect(achado).to eq(barbershop)
    end

    it "não deixa o subdomínio de outra barbershop escapar por prefixo" do
      Barbershop.create!(name: "Casa Alfa", slug: "casa-alfa")
      alvo = Barbershop.create!(name: "Casa Central Filial", slug: "casa-alfa-filial")

      achado = described_class.new("casa-alfa-filial.#{app_host}", app_host).call

      expect(achado).to eq(alvo)
      expect(achado).not_to eq(Barbershop.find_by(slug: "casa-alfa"))
    end
  end

  def dev_host
    # Em desenvolvimento o host base é `senior-r.localhost`, para que o browser
    # resolva `localhost` de forma previsível sem editar /etc/hosts.
    described_class::DEVELOPMENT_ROOT_HOST
  end
end
