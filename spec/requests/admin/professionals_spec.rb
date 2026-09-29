require 'rails_helper'

RSpec.describe "Admin::Professionals", type: :request do
  let(:admin) { create_admin_for }
  let(:professional) { Professional.create!(name: "Profissional Teste") }

  before { sign_in admin }

  describe "POST /admin/professionals" do
    # 422 e não 200: o Turbo trata 200 como sucesso e descarta o corpo da
    # resposta, então o operador veria o formulário de volta sem erro visível.
    it "responds 422 when the name is blank" do
      post admin_professionals_path, params: { professional: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "responds 422 when the name is already taken" do
      post admin_professionals_path, params: { professional: { name: professional.name } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "creates the professional and redirects when valid" do
      post admin_professionals_path, params: { professional: { name: "Novo profissional" } }

      expect(response).to redirect_to(admin_professionals_path)
    end

    it "persists the professional when valid" do
      post admin_professionals_path, params: { professional: { name: "Novo profissional" } }

      expect(tenant_records(Professional).find_by(name: "Novo profissional")).to be_present
    end
  end

  describe "PATCH /admin/professionals/:id" do
    it "responds 422 when the name is blank" do
      patch admin_professional_path(professional), params: { professional: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "responds 422 when the name collides with another professional" do
      other = Professional.create!(name: "Outro profissional")

      patch admin_professional_path(other), params: { professional: { name: professional.name } }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "renames and redirects when valid" do
      patch admin_professional_path(professional), params: { professional: { name: "Renomeado" } }

      expect(response).to redirect_to(admin_professionals_path)
    end

    it "persists the new name when valid" do
      patch admin_professional_path(professional), params: { professional: { name: "Renomeado" } }

      expect(professional.reload.name).to eq("Renomeado")
    end
  end
end
