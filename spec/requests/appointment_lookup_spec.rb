require "rails_helper"

RSpec.describe "AppointmentsController#lookup_new / #lookup", type: :request do
  let(:professional) { Professional.create!(name: "Profissional Teste") }
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }

  # O formulário aceita qualquer pontuação (ver o comentário em
  # `AppointmentsController#find_client_by_phone`): o cliente é cadastrado
  # com o telefone "cru" do formulário de agendamento, e a busca entra
  # formatada de outro jeito, para provar que a comparação normaliza os dois
  # lados e não só bate string crua contra string crua.
  let(:client) { Client.create!(name: "Cliente Teste", phone: "(19) 99999-8888") }

  # Cria um agendamento válido (a validação `start_at_cannot_be_in_the_past`
  # só existe `on: :create`) e então reescreve `start_at`/`end_at`/`status`
  # por `update_columns`, que pula validações — é o mesmo truque que
  # `spec/requests/appointments_spec.rb` já usa para simular um agendamento
  # `canceled`/`completed` sem reescrever a regra de negócio aqui.
  def book!(start_at:, client: self.client, status: :pending, professional: self.professional, service: self.service)
    # O slot de criação é só um valor futuro válido para passar a validação
    # `start_at_cannot_be_in_the_past` (`on: :create`) — o `start_at` real do
    # teste é gravado depois, por `update_columns`. Cada chamada usa um dia
    # futuro DIFERENTE (`@book_sequence`): duas chamadas no mesmo exemplo
    # compartilham `professional`, e nascer as duas no MESMO slot violaria a
    # exclusion constraint do banco (`appointments_no_active_overlap`) antes
    # mesmo de `update_columns` mover qualquer uma delas para o horário final.
    @book_sequence = (@book_sequence || 0) + 1
    creation_start_at = (100 + @book_sequence).days.from_now.change(hour: 10, min: 0)
    duration = service.duration_minutes.minutes
    appointment = create_test_appointment!(
      professional: professional, client: client, service: service,
      start_at: creation_start_at,
      end_at: creation_start_at + duration
    )
    appointment.update_columns(
      start_at: start_at,
      end_at: start_at + duration,
      status: Appointment.statuses.fetch(status.to_s)
    )
    appointment
  end

  describe "GET /agendamento/consultar" do
    it "renders the phone form" do
      get appointment_lookup_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Consultar agendamento")
    end
  end

  describe "POST /agendamento/consultar" do
    it "requires a phone number" do
      post appointment_lookup_search_path, params: { phone: "" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Informe um telefone")
    end

    context "with a single upcoming appointment" do
      it "shows the appointment receipt" do
        appointment = book!(start_at: 3.days.from_now.change(hour: 10, min: 0))

        post appointment_lookup_search_path, params: { phone: "19999998888" }

        expect(response).to have_http_status(:success)
        expect(response.body).to include(service.name)
        expect(response.body).to include(professional.name)
        expect(response.body).to include(client.masked_phone)
        # O número completo nunca aparece — só os últimos dígitos, igual à
        # página de confirmação por token.
        expect(response.body).not_to include("999998888")
        expect(response.body).to include(appointment.status_label)
      end

      it "finds the client regardless of phone punctuation" do
        book!(start_at: 3.days.from_now.change(hour: 10, min: 0))

        post appointment_lookup_search_path, params: { phone: "(19) 9 9999-8888" }

        expect(response).to have_http_status(:success)
        expect(response.body).to include(client.masked_phone)
      end
    end

    context "with multiple upcoming appointments" do
      it "lists every upcoming appointment instead of picking one" do
        other_service = Service.create!(name: "Barba", duration_minutes: 20)
        first_appointment = book!(start_at: 2.days.from_now.change(hour: 9, min: 0))
        second_appointment = book!(start_at: 5.days.from_now.change(hour: 14, min: 0), service: other_service)

        post appointment_lookup_search_path, params: { phone: "19999998888" }

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Encontramos mais de um agendamento")
        expect(response.body).to include(first_appointment.service.name)
        expect(response.body).to include(second_appointment.service.name)
      end
    end

    context "when the phone matches no client" do
      it "shows the not-found state instead of crashing" do
        post appointment_lookup_search_path, params: { phone: "11900000000" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Não encontramos nenhum cadastro")
      end
    end

    context "when the client only has past appointments" do
      it "falls back to the most recent past, non-canceled appointment" do
        past_appointment = book!(start_at: 10.days.ago.change(hour: 10, min: 0), status: :completed)

        post appointment_lookup_search_path, params: { phone: "19999998888" }

        expect(response).to have_http_status(:success)
        expect(response.body).to include(past_appointment.service.name)
      end

      it "shows the not-found state when the only past appointment was canceled" do
        book!(start_at: 10.days.ago.change(hour: 10, min: 0), status: :canceled)

        post appointment_lookup_search_path, params: { phone: "19999998888" }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Não encontramos nenhum agendamento")
      end
    end

    context "when the phone belongs to a client at a different barbershop" do
      it "never finds a client that belongs to a different barbershop" do
        outro_telefone = "11955554444"

        within_tenant(other_barbershop) do
          outro_profissional = Professional.create!(name: "Profissional de Outra Barbearia")
          outro_servico = Service.create!(name: "Corte de Outra Barbearia", duration_minutes: 30)
          outro_cliente = Client.create!(name: "Cliente de Outra Barbearia", phone: outro_telefone)
          create_test_appointment!(
            professional: outro_profissional, client: outro_cliente, service: outro_servico,
            start_at: 3.days.from_now.change(hour: 10, min: 0),
            end_at: 3.days.from_now.change(hour: 10, min: 30)
          )
        end

        # A requisição continua resolvendo `test_barbershop` pelo host (ver
        # `config.before(type: :request) { host! tenant_host }` em
        # `rails_helper.rb`): o telefone existe no banco, só não NESTE tenant.
        post appointment_lookup_search_path, params: { phone: outro_telefone }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Não encontramos nenhum cadastro")
        expect(response.body).not_to include("Cliente de Outra Barbearia")
      end
    end
  end

  describe "o botão no cabeçalho" do
    it "links to the lookup form instead of rendering a static span" do
      get root_path

      expect(response.body).to include(%(href="#{appointment_lookup_path}"))
      expect(response.body).not_to include('role="presentation">Consultar Agendamento')
    end
  end
end
