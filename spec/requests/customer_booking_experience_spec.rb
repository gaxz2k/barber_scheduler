require 'rails_helper'

RSpec.describe "Customer booking experience", type: :request do
  # These request examples intentionally assert several parts of one public flow.
  # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:professional) { Professional.create!(name: "Gustavo") }
  let(:tomorrow) { Date.current + 1 }
  let(:available_start) { tomorrow.in_time_zone.change(hour: 9, min: 0) }

  def confirmation_params
    {
      appointment: {
        service_id: service.id,
        professional_id: professional.id,
        date: tomorrow.iso8601,
        start_at: available_start.iso8601,
        client_name: "Maria da Silva",
        client_phone: "19999998888"
      }
    }
  end

  before do
    Appointment.delete_all
    Service.delete_all
    Professional.delete_all
    Client.delete_all
  end

  describe "GET /" do
    it "returns a successful response" do
      get root_path

      expect(response).to have_http_status(:success)
    end

    it "does not expose appointments through sequential ids" do
      get "/appointments/1"

      expect(response).to have_http_status(:not_found)
    end

    it "opens directly on the service selection step" do
      service
      professional

      get root_path

      expect(response.body).to include("Escolha um serviço", "Corte", "30 min")
      expect(response.body).to include("Etapas do agendamento")
    end

    it "explains when services are not configured yet" do
      get root_path

      expect(response.body).to include("Ainda não há serviços cadastrados")
    end

    it "does not expose existing clients on the public entry point" do
      Client.create!(name: "Cliente Privado", phone: "11999999999")
      service
      professional

      get root_path

      expect(response.body).not_to include("Cliente Privado")
    end

    it "links a selected service to the professional step" do
      service

      get root_path

      expect(response.body).to include(new_appointment_path(service: service.id))
    end
  end

  describe "GET /appointments/new" do
    it "explains when no professional is configured" do
      service

      get new_appointment_path(service: service.id)

      expect(response.body).to include("Ainda não há profissionais disponíveis")
    end

    it "presents the professional step after a service is selected" do
      service
      professional

      get new_appointment_path(service: service.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Escolha seu profissional", professional.name)
      expect(response.body).not_to include("client_id")
    end

    it "renders a selected service even when the token attribute cache is stale" do
      service
      professional
      original_ignored_columns = Appointment.ignored_columns

      begin
        Appointment.ignored_columns += [ "confirmation_token" ]
        Appointment.reset_column_information

        get new_appointment_path(service: service.id)

        expect(response).to have_http_status(:success)
      ensure
        Appointment.ignored_columns -= [ "confirmation_token" ]
        Appointment.ignored_columns |= original_ignored_columns
        Appointment.reset_column_information
      end
    end

    it "presents future available times after a professional and date are selected" do
      service
      professional

      get new_appointment_path(
        service: service.id,
        professional: professional.id,
        date: tomorrow.iso8601
      )

      expect(response.body).to include("Escolha o melhor horário", "09:00")
    end

    it "does not preselect an unknown professional" do
      service
      professional

      get new_appointment_path(service: service.id, professional: "999999")

      expect(response.body).not_to include("value=\"999999\" checked")
    end
  end

  describe "GET /appointments/availability" do
    it "returns future slots as JSON" do
      service
      professional

      get availability_path(
        service_id: service.id,
        professional_id: professional.id,
        date: tomorrow.iso8601
      )

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body.fetch("slots")).to include(
        hash_including("value" => available_start.iso8601, "label" => "09:00")
      )
    end

    it "rejects an unknown service" do
      professional

      get availability_path(service_id: "999999", professional_id: professional.id, date: tomorrow.iso8601)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a date outside the safe booking range without raising" do
      service
      professional

      expect {
        get availability_path(
          service_id: service.id,
          professional_id: professional.id,
          date: "999999999-01-01"
        )
      }.not_to raise_error

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a date beyond the conservative one-year booking horizon" do
      service
      professional

      get availability_path(
        service_id: service.id,
        professional_id: professional.id,
        date: (Date.current + 1.year + 1.day).iso8601
      )

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a malformed date without raising" do
      service
      professional

      expect {
        get availability_path(
          service_id: service.id,
          professional_id: professional.id,
          date: "not-a-date"
        )
      }.not_to raise_error

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /appointments" do
    def valid_params
      {
        appointment: {
          service_id: service.id,
          professional_id: professional.id,
          date: tomorrow.iso8601,
          start_at: available_start.iso8601,
          client_name: "Maria da Silva",
          client_phone: "(19) 99999-8888"
        }
      }
    end

    it "rejects a start time from a different date than the selected date" do
      service
      professional
      params = valid_params
      params[:appointment][:start_at] = (tomorrow + 1.day).in_time_zone.change(hour: 9, min: 0).iso8601

      post appointments_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(Appointment.count).to eq(0)
    end

    it "rejects a start time that is not strict ISO 8601" do
      service
      professional
      params = valid_params
      params[:appointment][:start_at] = available_start.strftime("%Y-%m-%dT%H:%M:%S%z")

      post appointments_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(Appointment.count).to eq(0)
    end

    it "rejects a start time with a permissive parser format" do
      service
      professional
      params = valid_params
      params[:appointment][:start_at] = available_start.iso8601.sub("T", " ")

      post appointments_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(Appointment.count).to eq(0)
    end

    it "rejects a timezone offset that crosses local midnight" do
      service
      professional
      params = valid_params
      params[:appointment][:start_at] = "2026-09-26T09:00:00+14:00"

      post appointments_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(Appointment.count).to eq(0)
    end

    it "rejects an invalid timezone offset" do
      service
      professional
      params = valid_params
      params[:appointment][:start_at] = available_start.strftime("%Y-%m-%dT%H:%M:%S-99:00")

      post appointments_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(Appointment.count).to eq(0)
    end

    it "rejects an offset beyond fourteen hours" do
      service
      professional
      params = valid_params
      params[:appointment][:start_at] = "2026-09-26T09:00:00+14:01"

      post appointments_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(Appointment.count).to eq(0)
    end

    it "rejects a parser-normalized midnight time" do
      service
      professional
      params = valid_params
      params[:appointment][:start_at] = "2026-09-26T24:00:00-03:00"

      post appointments_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(Appointment.count).to eq(0)
    end

    it "creates a client from the visitor data and redirects to a protected confirmation" do
      service
      professional

      expect {
        post appointments_path, params: valid_params
      }.to change(Appointment, :count).by(1).and change(Client, :count).by(1)

      appointment = Appointment.last
      expect(appointment.client.name).to eq("Maria da Silva")
      expect(appointment.client.phone).to eq("19999998888")
      expect(response).to have_http_status(:redirect)
      expect(response.location).to start_with("http://www.example.com/appointments/confirmation/")
    end

    it "does not expose the old client selector or accept client_id" do
      service
      professional
      params = valid_params
      params[:appointment][:client_id] = "999999"

      post appointments_path, params: params

      expect(response).to redirect_to(%r{\Ahttp://www\.example\.com/appointments/confirmation/})
      expect(Appointment.last.client.name).to eq("Maria da Silva")
    end

    it "shows validation errors without creating a client" do
      service
      professional
      params = valid_params
      params[:appointment][:client_name] = ""
      params[:appointment][:client_phone] = "123"

      expect {
        post appointments_path, params: params
      }.not_to change(Client, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Informe seu nome e um telefone válido")
    end

    it "rejects a malformed appointment payload without raising" do
      expect {
        post appointments_path, params: { appointment: "invalid" }
      }.not_to raise_error

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "shows a selection error before the schedule step" do
      post appointments_path, params: { appointment: { service_id: nil, professional_id: nil, date: nil } }

      expect(response.body).to include(
        "Escolha um serviço",
        "Selecione serviço, profissional e data válidos.",
        'id="error_explanation"'
      )
    end

    it "mirrors the maximum booking date in the form" do
      service
      professional

      get new_appointment_path(
        service: service.id,
        professional: professional.id,
        date: tomorrow.iso8601
      )

      expect(response.body).to include(%(max="#{(Date.current + 1.year).iso8601}"))
    end

    it "rejects non-scalar appointment identifiers and date values" do
      service
      professional

      [ :service_id, :professional_id, :date ].each do |field|
        params = valid_params
        params[:appointment][field] = [ "unexpected" ]

        expect {
          post appointments_path, params: params
        }.not_to raise_error
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    it "requires an explicit future date when creating" do
      service
      professional
      params = valid_params
      params[:appointment].delete(:date)

      post appointments_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(Appointment.count).to eq(0)
    end

    it "rejects a date outside the safe booking range without raising" do
      service
      professional
      params = valid_params
      params[:appointment][:date] = "999999999-01-01"

      expect {
        post appointments_path, params: params
      }.not_to raise_error

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a malformed date without raising" do
      service
      professional
      params = valid_params
      params[:appointment][:date] = "not-a-date"

      expect {
        post appointments_path, params: params
      }.not_to raise_error

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "keeps an invalid date on the schedule step with an error" do
      service
      professional
      params = valid_params
      params[:appointment][:date] = "not-a-date"

      post appointments_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(
        "Escolha data e horário",
        "Selecione serviço, profissional e data válidos.",
        'id="error_explanation"',
        'name="appointment[date]"'
      )
    end

    it "rejects an out-of-range start time without raising" do
      service
      professional
      params = valid_params
      params[:appointment][:start_at] = "2026-99-99T10:00:00-03:00"

      expect {
        post appointments_path, params: params
      }.not_to raise_error

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /appointments/confirmation/:token" do
    it "shows the visitor name and phone with a valid token" do
      service
      professional
      post appointments_path, params: confirmation_params
      token = response.location.split("/").last

      get appointment_confirmation_path(token: token)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Maria da Silva", "19999998888")
    end

    it "rejects an expired confirmation token" do
      service
      professional
      post appointments_path, params: confirmation_params
      token = response.location.split("/").last
      appointment = Appointment.find_by!(confirmation_token: token)
      appointment.update_columns(confirmation_expires_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations

      get appointment_confirmation_path(token: token)

      expect(response).to redirect_to(new_appointment_path)
    end

    it "keeps the selected future date after a failed submission" do
      service
      professional
      params = confirmation_params
      params[:appointment][:client_name] = ""

      post appointments_path, params: params

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(available_start.strftime("%H:%M"), "Informe seu nome")
    end

    it "preselects the chosen slot after a failed submission" do
      service
      professional
      params = confirmation_params
      params[:appointment][:client_name] = ""

      post appointments_path, params: params

      checked = CGI.unescapeHTML(response.body).scan(/<input[^>]*name="appointment\[start_at\]"[^>]*>/).select { |tag| tag.include?("checked") }
      result = checked.any? { |tag| tag.include?(available_start.iso8601) }

      expect(result).to be(true)
    end

    it "rejects an invalid confirmation token" do
      get "/appointments/confirmation/invalid-token"

      expect(response).to redirect_to(new_appointment_path)
    end

    it "rejects a terminal confirmation token" do
      service
      professional
      post appointments_path, params: confirmation_params
      token = response.location.split("/").last
      appointment = Appointment.find_by!(confirmation_token: token)
      appointment.update!(status: :canceled)

      get appointment_confirmation_path(token: token)

      expect(response).to redirect_to(new_appointment_path)
    end

    it "rejects a completed confirmation token" do
      service
      professional
      post appointments_path, params: confirmation_params
      token = response.location.split("/").last
      appointment = Appointment.find_by!(confirmation_token: token)
      appointment.update!(status: :completed)

      get appointment_confirmation_path(token: token)

      expect(response).to redirect_to(new_appointment_path)
    end
  end
  # rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength
end
