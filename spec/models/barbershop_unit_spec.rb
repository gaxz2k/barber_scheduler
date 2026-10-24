require "rails_helper"

# Unidades: a mesma barbearia pode ter uma ou mais unidades, e a unidade é
# escolhida na URL.
#
# A regra central, e a que é fácil errar: a unidade NÃO é um tenant novo.
# `barbershops` continua sendo a fronteira de isolamento. Uma unidade é um
# recorte dentro dela — o mesmo dono, o mesmo admin, o mesmo catálogo, com
# profissionais e horários próprios.
RSpec.describe "unidades de uma barbearia", type: :model do
  let!(:barbearia) { Barbershop.create!(name: "Barbearia Units", slug: "units") }
  let!(:outra_barbershop) { Barbershop.create!(name: "Outra", slug: "outra-units") }

  # Duas unidades da MESMA barbearia, e uma de outra barbearia com o MESMO slug
  # — para provar que a fronteira continua sendo a barbearia e não a unidade.
  # `let!` roda antes do `before` que liga Current, e a validação de tenant
  # recusa gravar sem contexto. `within_tenant` liga Current, cria e restaura.
  let!(:centro) do
    within_tenant(barbearia) do
      BarbershopUnit.create!(barbershop: barbearia, name: "Unidade Centro", slug: "centro",
                             address: "Rua Central, 100", phone: "(11) 3000-1000")
    end
  end
  let!(:jardim) do
    within_tenant(barbearia) do
      BarbershopUnit.create!(barbershop: barbearia, name: "Unidade Jardim", slug: "jardim",
                             address: "Av. Jardim, 900", phone: "(11) 3000-9000")
    end
  end
  let!(:unidade_estrangeira) do
    within_tenant(outra_barbershop) do
      BarbershopUnit.create!(barbershop: outra_barbershop, name: "Unidade de Outra", slug: "centro")
    end
  end

  before { Current.barbershop = barbearia }

  describe "pertencimento" do
    it "a unidade pertence a uma barbershop" do
      expect(centro.barbershop).to eq(barbearia)
    end

    it "a mesma barbearia tem mais de uma unidade" do
      # A barbearia nasce com a unidade "principal", então "mais de uma" são
      # três aqui. O que importa é que as duas criadas existam e sejam dela.
      expect(barbearia.unidades).to include(centro, jardim)
      expect(barbearia.unidades.where(slug: "principal").count).to eq(1)
    end

    it "o slug é único por barbearia, não no sistema inteiro" do
      # A outra barbearia tem uma unidade com o mesmo slug "centro". Se o slug
      # fosse global, a segunda seria recusada — e a fronteira de isolamento
      # seria o slug, não a barbearia.
      expect(unidade_estrangeira.persisted?).to be true
      expect(unidade_estrangeira.slug).to eq(centro.slug)
    end

    it "recusa uma unidade de outra barbearia" do
      Current.barbershop = outra_barbershop

      unidade = BarbershopUnit.new(barbershop: barbearia, name: "Invasora", slug: "invasora")

      expect(unidade).to be_invalid
      expect(unidade.errors[:barbershop]).to be_present
    end

    it "recusa uma segunda unidade com o mesmo slug na mesma barbearia" do
      duplicada = BarbershopUnit.new(barbershop: barbearia, name: "Centro 2", slug: "centro")

      expect(duplicada).to be_invalid
      expect(duplicada.errors[:slug]).to be_present
    end
  end

  describe "profissionais" do
    it "o profissional pertence a uma unidade" do
      profissional = Professional.create!(name: "Do Centro", barbershop_unit: centro)

      expect(profissional.barbershop_unit).to eq(centro)
    end

    it "a agenda da unidade não mostra o profissional de outra unidade" do
      do_centro = Professional.create!(name: "Rafael", barbershop_unit: centro)
      do_jardim = Professional.create!(name: "Thiago", barbershop_unit: jardim)

      expect(Professional.for_unit(centro)).to contain_exactly(do_centro)
      expect(Professional.for_unit(centro)).not_to include(do_jardim)
    end

    it "um profissional sem unidade aparece em todas" do
      # Sem unidade o profissional atende em qualquer uma — é quem atende em
      # todas, e esconder dele de uma unidade seria inventar uma restrição que
      # ninguém cadastrou.
      geral = Professional.create!(name: "Geral")

      expect(Professional.for_unit(centro)).to include(geral)
      expect(Professional.for_unit(jardim)).to include(geral)
    end

    it "não atravessa a fronteira da barbearia" do
      # A unidade da outra barbearia não pode aparecer, mesmo com o mesmo slug.
      # Forçada direto no banco porque a validação já recusa esse caminho — e
      # é justamente o estado que um import antigo deixaria, que a leitura tem
      # de continuar bloqueando.
      profissional = Professional.create!(name: "Fronteiro")
      profissional.update_column(:barbershop_unit_id, unidade_estrangeira.id)

      expect(Professional.for_unit(centro).pluck(:name)).not_to include("Fronteiro")
      expect(Professional.for_unit(jardim).pluck(:name)).not_to include("Fronteiro")
    end

    it "recusa profissional de unidade de outra barbearia" do
      candidato = Professional.new(name: "Invasor", barbershop_unit: unidade_estrangeira)

      expect(candidato).to be_invalid
      expect(candidato.errors[:barbershop_unit]).to be_present
    end
  end

  describe "resolução pela URL" do
    it "acha a unidade pelo slug dentro da barbearia do contexto" do
      achada = BarbershopUnit.for_slug("jardim")

      expect(achada).to eq(jardim)
    end

    it "devolve nil para um slug que não existe" do
      expect(BarbershopUnit.for_slug("inexistente")).to be_nil
    end

    it "devolve nil para o slug de outra barbearia" do
      # "centro" existe em outra_barbershop. Dentro do contexto de `barbearia`
      # ele tem de resolver para a unidade CENTRO, e não para a homônima.
      achada = BarbershopUnit.for_slug("centro")

      expect(achada).to eq(centro)
      expect(achada).not_to eq(unidade_estrangeira)
    end
  end

  describe "catálogo" do
    it "os serviços são da barbearia, compartilhados entre as unidades" do
      # Serviço é do tenant, não da unidade: o cardápio não se replica por
      # unidade, e duplicá-lo daria duas fontes de verdade para o mesmo preço.
      servico = Service.create!(name: "Corte", duration_minutes: 30, price_cents: 6000)

      expect(barbearia.unidades.count).to eq(3)
      expect(centro.barbershop.services).to include(servico)
      expect(jardim.barbershop.services).to include(servico)
    end
  end
end
