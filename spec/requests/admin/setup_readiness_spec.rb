require "rails_helper"

# O painel diz se a barbearia pode atender, e diz o que falta.
#
# Hoje a home afirma "Seu painel está pronto para operar" sem olhar nada: uma
# barbearia recém-criada, sem serviço e sem profissional, é declarada pronta na
# tela que deveria avisar. Um painel que só descobre o problema na primeira
# reclamação do cliente é um painel que não serve para isso.
RSpec.describe "Painel administrativo de barbearia incompleta", type: :request do
  let!(:barbearia) { Barbershop.create!(name: "Barbearia Incompleta", slug: "incompleta-#{SecureRandom.hex(4)}") }
  let(:unidade) { within_tenant(barbearia) { barbearia.unidades.order(:id).first } }

  let!(:admin) { create_admin_for(barbearia) }

  before { sign_in admin }

  it "avisa que a barbearia ainda não está pronta" do
    get admin_root_path, headers: { "HTTP_HOST" => tenant_host(barbearia) }

    expect(response.body).to include("Ainda falta")
  end

  it "não afirma que está pronto quando não está" do
    get admin_root_path, headers: { "HTTP_HOST" => tenant_host(barbearia) }

    expect(response.body).not_to include("pronto para operar")
  end

  it "aponta os itens que faltam" do
    get admin_root_path, headers: { "HTTP_HOST" => tenant_host(barbearia) }

    expect(response.body).to include("Serviços", "Profissionais", "Horário de funcionamento")
  end

  it "leva a cada item faltante na tela certa" do
    get admin_root_path, headers: { "HTTP_HOST" => tenant_host(barbearia) }

    expect(response.body).to include(admin_services_path)
    expect(response.body).to include(admin_professionals_path)
  end

  it "afirma que está pronto quando a barbearia está completa" do
    within_tenant(barbearia) do
      Service.create!(name: "Corte", duration_minutes: 30)
      Professional.create!(name: "Prof", barbershop_unit: unidade)
      unidade.update!(opening_hours: (1..6).to_h { |d| [ d.to_s, { "open" => "08:00", "close" => "19:00" } ] })
    end

    get admin_root_path, headers: { "HTTP_HOST" => tenant_host(barbearia) }

    expect(response.body).to include("pronto para atender")
    expect(response.body).not_to include("Ainda falta")
  end

  describe "isolamento entre barbearias" do
    it "o painel de uma barbearia não mostra a falta de cadastro de outra" do
      outra = Barbershop.create!(name: "Outra Incompleta", slug: "outra-#{SecureRandom.hex(4)}")
      within_tenant(outra) do
        Service.create!(name: "Corte Alheio", duration_minutes: 30)
      end

      get admin_root_path, headers: { "HTTP_HOST" => tenant_host(barbearia) }

      expect(response.body).to include("Ainda falta")
    end
  end
end
