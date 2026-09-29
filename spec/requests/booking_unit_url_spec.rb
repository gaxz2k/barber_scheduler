require "rails_helper"

# A unidade é escolhida na URL, não deduzida.
#
# `/barbearia/unidades/centro` é a escolha do cliente, e é o que sobrevive à
# troca de unidade depois: o link de confirmação carrega a unidade gravada, e a
# URL do agendamento carrega a que o cliente escolheu. Deduzir a principal
# transformaria "não informado" em "esta loja" sem ninguém pedir.
RSpec.describe "unidade na URL do agendamento", type: :request do
  let!(:barbearia) { Barbershop.create!(name: "Barbearia URL", slug: "url-#{SecureRandom.hex(4)}") }
  # Pelo helper e não por `unidades.order(:id)`: a agenda depende do horario de
  # funcionamento, e o helper e quem define o expediente de teste.
  let!(:unidade) { test_unit_for(barbearia) }
  let(:servico) { within_tenant(barbearia) { Service.create!(name: "Corte URL", duration_minutes: 30) } }
  let(:profissional) { within_tenant(barbearia) { Professional.create!(name: "Prof URL", barbershop_unit: unidade) } }
  let(:data) { (Date.current + 3).to_s }
  let(:slot) do
    within_tenant(barbearia) do
      AvailableSlots::Calculator.new(professional: profissional, date: Date.parse(data), service: servico, barbershop_unit: unidade).call.first
    end
  end

  it "agenda na unidade da URL" do
    post within_tenant(barbearia) { appointments_path(unidade_slug: unidade.slug) },
         params: { appointment: { service_id: servico.id, professional_id: profissional.id,
                                   date: data, start_at: slot.iso8601,
                                   client_name: "Cliente URL", client_phone: "11987650011" } },
         headers: { "HTTP_HOST" => tenant_host(barbearia) }

    agendamento = within_tenant(barbearia) { Appointment.order(:id).last }
    expect(agendamento.barbershop_unit_id).to eq(unidade.id)
  end

  it "recusa uma unidade de outra barbearia" do
    outra = Barbershop.create!(name: "Outra URL", slug: "outra-#{SecureRandom.hex(4)}")
    alheia = within_tenant(outra) do
      BarbershopUnit.create!(barbershop: outra, name: "Jardim Alheio", slug: "jardim-#{SecureRandom.hex(4)}")
    end

    # Slug distinto do da unidade válida de propósito: as duas barbearias já
    # têm uma unidade "principal", e pedir essa na URL resolveria a unidade da
    # própria barbearia. O exemplo mediria homônimo, não a fronteira.
    post within_tenant(barbearia) { appointments_path(unidade_slug: alheia.slug) },
         params: { appointment: { service_id: servico.id, professional_id: profissional.id,
                                   date: data, start_at: slot.iso8601,
                                   client_name: "Cliente URL", client_phone: "11987650012" } },
         headers: { "HTTP_HOST" => tenant_host(barbearia) }

    expect(within_tenant(barbearia) { Appointment.count }).to eq(0)
  end

  it "recusa agendar sem unidade na URL" do
    post within_tenant(barbearia) { appointments_path },
         params: { appointment: { service_id: servico.id, professional_id: profissional.id,
                                   date: data, start_at: slot.iso8601,
                                   client_name: "Cliente URL", client_phone: "11987650013" } },
         headers: { "HTTP_HOST" => tenant_host(barbearia) }

    expect(within_tenant(barbearia) { Appointment.count }).to eq(0)
  end
end
