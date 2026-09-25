require 'rails_helper'

RSpec.describe "Customer booking experience", type: :request do
  describe "GET /" do
    it "returns a successful response" do
      get root_path

      expect(response).to have_http_status(:success)
    end

    it "presents the booking entry point" do
      get root_path

      expect(response.body).to include("Barbearia Senhor R", "Agendar um horário")
    end

    it "explains when the team is not configured yet" do
      get root_path

      expect(response.body).to include("Ainda não há profissionais cadastrados")
    end

    it "links an existing professional to the booking form" do
      professional = Professional.create!(name: "Gustavo")

      get root_path

      expect(response.body).to include(new_appointment_path(professional: professional.id))
    end
  end

  describe "GET /appointments/new" do
    it "explains when no professional is configured" do
      get new_appointment_path

      expect(response.body).to include("Ainda não há profissionais disponíveis")
    end

    it "returns a successful response" do
      get new_appointment_path

      expect(response).to have_http_status(:success)
    end

    it "presents the guided booking form" do
      get new_appointment_path

      expect(response.body).to include("Escolha seu profissional", "Seus dados", "Serviço")
    end

    it "preselects a professional passed in the query string" do
      professional = Professional.create!(name: "Gustavo")

      get new_appointment_path(professional: professional.id)

      expect(response.body).to include("value=\"#{professional.id}\" checked")
    end
  end

  describe "GET /users/sign_in" do
    it "uses the Portuguese branded login screen" do
      get new_user_session_path

      expect(response.body).to include("Entrar no painel", "E-mail", "Senha", "Esqueci minha senha")
    end
  end
end
