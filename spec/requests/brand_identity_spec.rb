# frozen_string_literal: true

require "rails_helper"

# A marca da casa vinha impressa à mão em quatro views, com o nome do
# barbearia original fixo. Estes specs existem para que trocar o nome do tenant
# não exija caçar string em view: o partial tem que refletir `Current.barbershop`
# e o model tem que derivar o que o partial usa.
RSpec.describe "Marca da casa", type: :request do
  def marca_esperada
    Current.barbershop.name
  end

  describe "Barbershop#monograma" do
    it "usa a inicial das duas primeiras palavras quando há várias" do
      expect(Barbershop.new(name: "Studio Navalha").monograma).to eq("SN")
      expect(Barbershop.new(name: "Casa do Navio").monograma).to eq("CN")
    end

    it "usa as duas primeiras letras quando o nome tem uma palavra só" do
      expect(Barbershop.new(name: "Espaço").monograma).to eq("ES")
    end

    it "não quebra com nome vazio" do
      expect(Barbershop.new(name: nil).monograma).to eq("")
    end
  end

  describe "Barbershop#nome_curto" do
    it "descarta o qualificador de uma palavra" do
      expect(Barbershop.new(name: "Studio Navalha").nome_curto).to eq("Navalha")
      expect(Barbershop.new(name: "Barbearia Aleluia").nome_curto).to eq("Aleluia")
    end

    it "descarta o qualificador de várias palavras, com a preposição junto" do
      # O corte posicional é o que evita "da Vila" e "de Cabelo" virarem
      # cabeçalho: sem tratar "da" como parte do qualificador, o primeiro
      # nome real seria a preposição.
      expect(Barbershop.new(name: "Salão da Vila").nome_curto).to eq("Vila")
      expect(Barbershop.new(name: "Studio de Cabelo").nome_curto).to eq("Cabelo")
    end

    it "não corta quando a primeira palavra é o próprio nome" do
      expect(Barbershop.new(name: "Espaço Villa").nome_curto).to eq("Espaço Villa")
    end

    it "devolve o nome inteiro quando ele é um qualificador só" do
      expect(Barbershop.new(name: "Barbearia").nome_curto).to eq("Barbearia")
    end
  end

  describe "partial shared/_brand" do
    # O `before` global já põe o `test_barbershop` em `Current`. Renomear o
    # tenant em vez de criar outro é o que faz a marca vir do host da
    # requisição: a marca precisa refletir quem a requisição resolveu, e o host
    # aponta para a barbearia do `test_barbershop`.
    let(:agenda) { get new_appointment_path }

    before { Current.barbershop.update!(name: "Studio Navalha") }

    it "mostra o monograma e o nome curto do tenant" do
      agenda
      expect(response.body).to include(">SN<").and include("Navalha")
    end

    it "usa a marca do tenant no título, não um nome fixo" do
      agenda
      expect(response.body).to include("Studio Navalha")
    end

    it "muda a marca quando a casa muda, sem nenhuma alteração no código" do
      Current.barbershop.update!(name: "Barbearia Aleluia")
      agenda

      expect(response.body).to include(">BA<").and include("Aleluia")
      expect(response.body).not_to include("Navalha")
    end

    it "reaproveita o mesmo partial nas telas de login" do
      get new_user_session_path
      expect(response.body).to include(">SN<")
    end
  end
end
