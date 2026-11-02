require 'rails_helper'

RSpec.describe "Admin::Professionals", type: :request do
  let(:admin) { create_admin_for }
  let(:regular_user) { User.create!(email: "user@example.com", password: "password123") }

  describe "GET /admin/professionals/new" do
    it "redirects anonymous visitors to sign in" do
      get new_admin_professional_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows a Portuguese access message after the redirect" do
      get new_admin_professional_path
      follow_redirect!

      expect(response.body).to include("Você precisa entrar no painel para acessar esta página.")
    end

    it "does not expose a translation fallback after the redirect" do
      get new_admin_professional_path
      follow_redirect!

      expect(response.body).not_to include("Translation missing")
    end

    it "redirects logged-in users who are not admin" do
      sign_in regular_user

      get new_admin_professional_path

      expect(response).to redirect_to(root_path)
    end

    it "is accessible to admins" do
      sign_in admin

      get new_admin_professional_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /admin/professionals" do
    it "does not let a non-admin create a professional" do
      sign_in regular_user

      expect {
        post admin_professionals_path, params: { professional: { name: "Richard" } }
      }.not_to change_tenant_count(Professional)
    end

    it "lets an admin create a professional" do
      sign_in admin

      expect {
        post admin_professionals_path, params: { professional: { name: "Richard" } }
      }.to change_tenant_count(Professional).by(1)
    end
  end

  # "Definir como padrão": grava `default_professional` na UNIDADE do
  # profissional (ver `BarbershopUnit#default_professional` para o porquê de
  # o padrão viver na unidade, e não no profissional ou na barbearia).
  # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength -- os exemplos de "redireciona com aviso"
  # e "recusa sem unidade" precisam confirmar o redirect E o texto do flash
  # na mesma requisição; separar em dois exemplos duplicaria a requisição
  # inteira só para dividir duas asserções que nascem do mesmo `patch`.
  describe "PATCH /admin/professionals/:id/set_default" do
    it "does not let a non-admin set a default professional" do
      sign_in regular_user
      unidade = test_unit_for(test_barbershop)
      professional = within_tenant { Professional.create!(name: "Rafael", barbershop_unit: unidade) }

      patch set_default_admin_professional_path(professional)

      expect(unidade.reload.default_professional_id).to be_nil
    end

    it "sets the professional's unit default_professional when the professional has a unit" do
      sign_in admin
      unidade = test_unit_for(test_barbershop)
      professional = within_tenant { Professional.create!(name: "Rafael", barbershop_unit: unidade) }

      patch set_default_admin_professional_path(professional)

      expect(unidade.reload.default_professional_id).to eq(professional.id)
    end

    it "redirects back to the professionals list with a success notice" do
      sign_in admin
      unidade = test_unit_for(test_barbershop)
      professional = within_tenant { Professional.create!(name: "Rafael", barbershop_unit: unidade) }

      patch set_default_admin_professional_path(professional)

      expect(response).to redirect_to(admin_professionals_path)
      follow_redirect!
      expect(response.body).to include("Profissional definido como padrão da unidade.")
    end

    it "replaces the previous default when a different professional is set" do
      sign_in admin
      unidade = test_unit_for(test_barbershop)
      rafael = within_tenant { Professional.create!(name: "Rafael", barbershop_unit: unidade) }
      bruno = within_tenant { Professional.create!(name: "Bruno", barbershop_unit: unidade) }
      patch set_default_admin_professional_path(rafael)

      patch set_default_admin_professional_path(bruno)

      expect(unidade.reload.default_professional_id).to eq(bruno.id)
    end

    # Um profissional sem unidade fixa atende em qualquer unidade (ver
    # `Professional.for_unit`) — não existe "a unidade dele" para gravar o
    # padrão, então a ação recusa em vez de escolher uma unidade arbitrária.
    it "refuses to set a professional without a fixed unit as default" do
      sign_in admin
      professional = Professional.create!(name: "Geral")

      patch set_default_admin_professional_path(professional)

      expect(response).to redirect_to(admin_professionals_path)
      follow_redirect!
      expect(response.body).to include("não tem uma unidade fixa")
    end
  end
  # rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength
end
