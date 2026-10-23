require 'rails_helper'

RSpec.describe "Barbershop online booking state", type: :model do
  it "accepts booking when no setting exists yet" do
    barbershop = Barbershop.create!(name: "Barbearia Sem Config", slug: "sem-config-#{SecureRandom.hex(4)}")

    expect(barbershop.online_booking_open?).to be(true)
  end

  it "accepts booking when the setting is explicitly enabled" do
    barbershop = Barbershop.create!(name: "Barbearia Ligada", slug: "ligada-#{SecureRandom.hex(4)}")
    within_tenant(barbershop) { ShopSetting.create!(barbershop: barbershop, online_booking_enabled: true) }

    expect(barbershop.reload.online_booking_open?).to be(true)
  end

  it "refuses booking when the owner pauses it" do
    barbershop = Barbershop.create!(name: "Barbearia Pausada", slug: "pausada-#{SecureRandom.hex(4)}")
    within_tenant(barbershop) { ShopSetting.create!(barbershop: barbershop, online_booking_enabled: false) }

    expect(barbershop.reload.online_booking_open?).to be(false)
  end

  it "falls back to a default pause message" do
    barbershop = Barbershop.create!(name: "Barbearia Padrão", slug: "padrao-#{SecureRandom.hex(4)}")
    within_tenant(barbershop) { ShopSetting.create!(barbershop: barbershop, online_booking_enabled: false) }

    expect(barbershop.reload.online_booking_pause_message).to eq(
      "Agendamento online pausado no momento. Fale com a equipe para marcar seu horário."
    )
  end

  it "uses the owner's custom pause message when present" do
    barbershop = Barbershop.create!(name: "Barbearia Custom", slug: "custom-#{SecureRandom.hex(4)}")
    config = { barbershop: barbershop, online_booking_enabled: false, online_booking_message: "Voltamos segunda-feira." }
    within_tenant(barbershop) { ShopSetting.create!(config) }

    expect(barbershop.reload.online_booking_pause_message).to eq("Voltamos segunda-feira.")
  end
end
