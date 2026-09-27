require "rails_helper"

# A unidade carrega o próprio horário, e é onde ele se cadastra.
#
# Sem esta tela não existe lugar para cadastrar o expediente, e `missing_setup`
# apontaria para o vazio. O caminho de prontidão e o caminho do CRUD de unidades
# são o mesmo.
RSpec.describe "Administração de unidades", type: :request do
  let!(:barbearia) { Barbershop.create!(name: "Barbearia Unidades", slug: "unidades-#{SecureRandom.hex(4)}") }
  let!(:admin) { User.create!(email: "admin-unidades@example.com", password: "password123", admin: true) }
  let(:unidade) { within_tenant(barbearia) { barbearia.unidades.order(:id).first } }

  before { sign_in admin }

  def headers_tenant
    { "HTTP_HOST" => tenant_host(barbearia) }
  end

  it "lista as unidades da barbearia" do
    within_tenant(barbearia) do
      BarbershopUnit.create!(barbershop: barbearia, name: "Jardim", slug: "jardim-#{SecureRandom.hex(4)}")
    end

    get admin_barbershop_units_path, headers: headers_tenant

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Jardim")
  end

  it "não lista unidade de outra barbearia" do
    outra = Barbershop.create!(name: "Outra Unidades", slug: "outra-un-#{SecureRandom.hex(4)}")
    within_tenant(outra) do
      BarbershopUnit.create!(barbershop: outra, name: "Loja Alheia", slug: "loja-#{SecureRandom.hex(4)}")
    end

    get admin_barbershop_units_path, headers: headers_tenant

    expect(response.body).not_to include("Loja Alheia")
  end

  it "cadastra uma unidade com horário de funcionamento" do
    post admin_barbershop_units_path,
         params: { barbershop_unit: { name: "Jardim", slug: "jardim-novo",
                                      opening_hours: { "1" => { "open" => "08:00", "close" => "19:00" } } } },
         headers: headers_tenant

    criada = within_tenant(barbearia) { BarbershopUnit.find_by(slug: "jardim-novo") }
    expect(criada).to be_present
    expect(criada.opening_hours.dig("1", "open")).to eq("08:00")
  end

  it "recusa horário com fechamento antes da abertura" do
    post admin_barbershop_units_path,
         params: { barbershop_unit: { name: "Jardim", slug: "jardim-ruim",
                                      opening_hours: { "1" => { "open" => "19:00", "close" => "08:00" } } } },
         headers: headers_tenant

    expect(within_tenant(barbearia) { BarbershopUnit.find_by(slug: "jardim-ruim") }).to be_nil
  end

  it "recusa horário com formato inválido" do
    post admin_barbershop_units_path,
         params: { barbershop_unit: { name: "Jardim", slug: "jardim-bad",
                                      opening_hours: { "1" => { "open" => "8h", "close" => "19:00" } } } },
         headers: headers_tenant

    expect(within_tenant(barbearia) { BarbershopUnit.find_by(slug: "jardim-bad") }).to be_nil
  end

  it "recusa unidade com slug repetido na mesma barbearia" do
    post admin_barbershop_units_path,
         params: { barbershop_unit: { name: "Repetida", slug: unidade.slug } },
         headers: headers_tenant

    expect(within_tenant(barbearia) { BarbershopUnit.where(slug: unidade.slug).count }).to eq(1)
  end

  it "atualiza o horário de uma unidade" do
    patch admin_barbershop_unit_path(unidade),
          params: { barbershop_unit: { opening_hours: { "2" => { "open" => "10:00", "close" => "20:00" } } } },
          headers: headers_tenant

    expect(unidade.reload.opening_hours.dig("2", "open")).to eq("10:00")
  end

  it "mostra o formulário de edição" do
    get edit_admin_barbershop_unit_path(unidade), headers: headers_tenant

    expect(response).to have_http_status(:ok)
  end
end
