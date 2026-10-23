require "rails_helper"

RSpec.describe "Administração do agendamento online", type: :request do
  let!(:barbearia) { Barbershop.create!(name: "Barbearia Pausável", slug: "pausavel-#{SecureRandom.hex(4)}") }
  let!(:admin) { create_admin_for(barbearia) }

  before { sign_in admin }

  def headers_tenant
    { "HTTP_HOST" => tenant_host(barbearia) }
  end

  def patch_shop_setting(params)
    patch admin_shop_setting_path, params: { shop_setting: params }, headers: headers_tenant
  end

  def shop_setting_de(barbershop)
    within_tenant(barbershop) { barbershop.reload.shop_setting }
  end

  it "mostra o formulário com o agendamento aceito por padrão" do
    get edit_admin_shop_setting_path, headers: headers_tenant

    expect(response.body).to include("checked")
  end

  it "pausa o agendamento online" do
    patch_shop_setting(online_booking_enabled: "0", online_booking_message: "Voltamos segunda.")

    expect(shop_setting_de(barbearia).online_booking_enabled).to be(false)
  end

  it "grava a mensagem customizada da pausa" do
    patch_shop_setting(online_booking_enabled: "0", online_booking_message: "Voltamos segunda.")

    expect(shop_setting_de(barbearia).online_booking_message).to eq("Voltamos segunda.")
  end

  it "religa o agendamento online" do
    within_tenant(barbearia) { ShopSetting.create!(barbershop: barbearia, online_booking_enabled: false) }
    patch_shop_setting(online_booking_enabled: "1")

    expect(shop_setting_de(barbearia).online_booking_enabled).to be(true)
  end

  context "when the admin does not belong to this barbershop" do
    before do
      outra = Barbershop.create!(name: "Outra Pausável", slug: "outra-pausavel-#{SecureRandom.hex(4)}")
      outro_admin = create_admin_for(outra)
      sign_out admin
      sign_in outro_admin
    end

    it "recusa a alteração" do
      patch_shop_setting(online_booking_enabled: "0")

      expect(response).to redirect_to(root_path)
    end

    it "não grava nada na barbearia alvo" do
      patch_shop_setting(online_booking_enabled: "0")

      expect(shop_setting_de(barbearia)).to be_nil
    end
  end
end
