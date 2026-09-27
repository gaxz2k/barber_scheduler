require "rails_helper"

# Isolamento entre barbearias: o requisito central do multi-tenant.
#
# Estes exemplos descrevem o que duas barbearias separadas têm de enxergar uma
# da outra. Cada um monta as duas barbearias e checa uma propriedade, então
# `MultipleExpectations` e `ExampleLength` não se aplicam: dividir um cenário
# em exemplos de um assertion só produziria exemplos que passam sozinhos.
#
# rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
RSpec.describe "isolamento entre barbearias", type: :model do
  # Uma barbearia precisa existir para os dados pertencerem a alguém. Aqui ela é
  # criada direto, sem depender de Current, porque o próprio exemplo é o teste
  # de que o vínculo importa.
  let!(:barbearia_a) do
    Barbershop.create!(name: "Barbearia A", slug: "barbearia-a-#{SecureRandom.hex(4)}")
  end

  let!(:barbearia_b) do
    Barbershop.create!(name: "Barbearia B", slug: "barbearia-b-#{SecureRandom.hex(4)}")
  end

  # Registros de mesmo nome nas duas barbearias. Se o escopo de tenant não
  # existir, as duas coleções devolvem os dois registros e o vazamento fica
  # visível.
  before do
    Current.barbershop = barbearia_a
    Professional.create!(name: "Gustavo")
    Service.create!(name: "Corte", duration_minutes: 30)
    Client.create!(name: "Maria", phone: "11987650001")

    Current.barbershop = barbearia_b
    Professional.create!(name: "Gustavo")
    Service.create!(name: "Corte", duration_minutes: 30)
    Client.create!(name: "Maria", phone: "11987650002")
  end

  describe "escopo de leitura" do
    it "o Professional da barbearia A não enxerga os da B" do
      Current.barbershop = barbearia_a

      expect(Professional.pluck(:name)).to eq([ "Gustavo" ])
    end

    it "o Serviço da barbearia A não enxerga os da B" do
      Current.barbershop = barbearia_a

      expect(Service.pluck(:name)).to eq([ "Corte" ])
    end

    it "o Cliente da barbearia A não enxerga os da B" do
      Current.barbershop = barbearia_a

      expect(Client.pluck(:name)).to eq([ "Maria" ])
    end

    it "cada barbearia vê os seus próprios registros" do
      Current.barbershop = barbearia_b

      expect(Professional.pluck(:name)).to eq([ "Gustavo" ])
      expect(Client.pluck(:phone)).to eq([ "11987650002" ])
    end

    it "sem contexto de tenant, nenhuma barbearia enxerga a outra" do
      Current.reset

      expect(Professional.count).to eq(0)
      expect(Service.count).to eq(0)
      expect(Client.count).to eq(0)
    end
  end

  describe "escopo de escrita" do
    it "recusa gravar apontando para outra barbearia" do
      Current.barbershop = barbearia_a

      # `Professional.new` herda o barbershop do contexto, então "gravar para
      # outra" só acontece quando o barbershop_id vem explícito. É esse o caso
      # perigoso: um controller que aceita barbershop_id do usuário escreveria
      # a linha na barbearia errada sem erro nenhum.
      registro = Professional.new(name: "Intruso", barbershop: barbearia_b)

      expect(registro).not_to be_valid
      expect(registro.errors[:barbershop]).to be_present
    end

    it "o contexto preenche o barbershop quando nenhum vem explícito" do
      Current.barbershop = barbearia_b

      registro = Professional.create!(name: "Novo")

      expect(registro.barbershop_id).to eq(barbearia_b.id)
    end

    it "recusa gravar fora de qualquer contexto" do
      Current.reset

      registro = Client.new(name: "Sem dono", phone: "11987650003")

      # A mensagem importa, não só a presença do erro: `errors[:barbershop]`
      # aparece tanto quando falta o contexto quanto quando o campo ficou em
      # branco, e checar só a presença faria este exemplo passar pela causa
      # errada.
      expect(registro).to be_invalid
      expect(registro.errors[:barbershop]).to include(/fora de uma requisição/)
    end

    it "aceita gravar na barbearia do contexto" do
      Current.barbershop = barbearia_b

      registro = Professional.new(name: "Novo")

      expect(registro).to be_valid
    end
  end

  describe "agenda" do
    it "Appointment da barbearia A não aparece para a B" do
      Current.barbershop = barbearia_a

      profissional = Professional.create!(name: "Agenda A")
      serviço = Service.create!(name: "Corte A", duration_minutes: 30)
      cliente = Client.create!(name: "Cliente A", phone: "11987650010")
      create_test_appointment!(professional: profissional, service: serviço, client: cliente,
                          start_at: 2.days.from_now.change(hour: 10, min: 0),
                          end_at: 2.days.from_now.change(hour: 10, min: 30))

      Current.barbershop = barbearia_b

      expect(Appointment.count).to eq(0)
    end

    it "cada barbearia tem a sua própria agenda" do
      Current.barbershop = barbearia_b

      profissional = Professional.create!(name: "Agenda B")
      serviço = Service.create!(name: "Corte B", duration_minutes: 30)
      cliente = Client.create!(name: "Cliente B", phone: "11987650011")
      create_test_appointment!(professional: profissional, service: serviço, client: cliente,
                          start_at: 2.days.from_now.change(hour: 14, min: 0),
                          end_at: 2.days.from_now.change(hour: 14, min: 30))

      expect(Appointment.count).to eq(1)
    end
  end

  describe "navegação de associação" do
    it "recusa um agendamento que aponta para registros de outra barbearia" do
      Current.barbershop = barbearia_b
      cliente_b = Client.create!(name: "Cliente B", phone: "11987650020")
      profissional_b = Professional.create!(name: "Profissional B")
      serviço_b = Service.create!(name: "Serviço B", duration_minutes: 30)

      Current.barbershop = barbearia_a
      appointment = Appointment.new(professional: profissional_b, client: cliente_b, service: serviço_b,
                                    start_at: 3.days.from_now.change(hour: 11, min: 0),
                                    end_at: 3.days.from_now.change(hour: 11, min: 30))

      # `belongs_to` guarda o id que recebeu e não consulta o destino durante a
      # validação, então sem esta checagem o registro passaria com o
      # `barbershop_id` da barbearia A apontando para linhas da B. A linha
      # ficaria invisível para a dona dos dados, deixaria o agendamento
      # duplicado passar (o validador de disponibilidade da B não a enxerga) e
      # estouraria 500 na página de confirmação.
      expect(appointment).to be_invalid
      expect(appointment.errors[:professional]).to be_present
      expect(appointment.errors[:client]).to be_present
      expect(appointment.errors[:service]).to be_present
    end

    it "a leitura da associação não devolve o cliente de outra barbearia" do
      Current.barbershop = barbearia_b
      cliente_b = Client.create!(name: "Cliente B", phone: "11987650021")

      Current.barbershop = barbearia_a
      cliente_a = Client.create!(name: "Cliente A", phone: "11987650022")
      profissional = Professional.create!(name: "Navegador Forcado")
      serviço = Service.create!(name: "Corte Forcado", duration_minutes: 30)
      appointment = create_test_appointment!(professional: profissional, service: serviço, client: cliente_a,
                                        start_at: 3.days.from_now.change(hour: 12, min: 0),
                                        end_at: 3.days.from_now.change(hour: 12, min: 30))
      # `update_column` pula as validações de propósito: é o único caminho em
      # Ruby que produz uma linha inconsistente sem precisar de SQL cru, e é o
      # estado que uma migration malfeita ou um import antigo deixariam.
      # rubocop:disable Rails/SkipsModelValidations
      appointment.update_column(:client_id, cliente_b.id)
      # rubocop:enable Rails/SkipsModelValidations

      expect(appointment.reload.client).to be_nil
    end
  end

  describe "link de confirmação" do
    it "a página funciona com Current vazio, resolvendo pelo token" do
      Current.barbershop = barbearia_a
      profissional = Professional.create!(name: "Confirmador")
      serviço = Service.create!(name: "Corte Confirmado", duration_minutes: 30)
      cliente = Client.create!(name: "Cliente Confirmado", phone: "11987650030")
      appointment = create_test_appointment!(professional: profissional, service: serviço, client: cliente,
                                        start_at: 4.days.from_now.change(hour: 13, min: 0),
                                        end_at: 4.days.from_now.change(hour: 13, min: 30))

      # O link vem por e-mail e o subdomínio não é confiável. Sem Current, o
      # appointment escopado não aparece — que é o comportamento correto do
      # escopo, e significa que a página precisa de um caminho explícito para
      # resolver pelo token.
      Current.reset
      achado = Appointment.without_tenant_scope.find_by(confirmation_token: appointment.confirmation_token)

      expect(achado).to be_present
      expect(achado.barbershop_id).to eq(barbearia_a.id)
    end
  end

  describe "escopo explícito por barbearia" do
    # `for_barbershop` é o que os specs usam para ler fora do contexto, e o
    # matcher `change_tenant_count` herda dele. Se o filtro saísse, todo teste
    # continuaria verde: os specs de request só têm uma barbearia em cena, e
    # "todos os tenants" e "esta barbearia" dão a mesma contagem. Este exemplo
    # existe só para que essa diferença tenha um teste.
    it "for_barbershop filtra pela barbearia pedida, ignorando o contexto" do
      Current.barbershop = barbearia_b
      cliente_b = Client.create!(name: "Cliente B", phone: "11987650040")

      Current.barbershop = barbearia_a
      cliente_a = Client.create!(name: "Cliente A", phone: "11987650041")

      # Comparado por conteúdo, e não por lista exata: outros exemplos do
      # arquivo criam clientes nas mesmas duas barbearias, e o que importa é que
      # a consulta traga a linha da sua e não a da outra.
      expect(Client.for_barbershop(barbearia_a).pluck(:id)).to include(cliente_a.id)
      expect(Client.for_barbershop(barbearia_a).pluck(:id)).not_to include(cliente_b.id)
      expect(Client.for_barbershop(barbearia_b).pluck(:id)).to include(cliente_b.id)
      expect(Client.for_barbershop(barbearia_b).pluck(:id)).not_to include(cliente_a.id)
    end
  end

  describe "contagem bruta" do
    it "as duas barbearias realmente têm registros duplicados" do
      # Sem esta âncora, os exemplos acima passariam a ser vacuosos se o
      # `before` deixasse de criar os registros.
      expect(Professional.without_tenant_scope.where(name: "Gustavo").count).to eq(2)
      expect(Client.without_tenant_scope.where(name: "Maria").count).to eq(2)
      expect(Service.without_tenant_scope.where(name: "Corte").count).to eq(2)
    end
  end
end
# rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength
