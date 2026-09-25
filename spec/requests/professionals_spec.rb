require 'rails_helper'

RSpec.describe "Admin::Professionals", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123", admin: true) }
  let(:regular_user) { User.create!(email: "user@example.com", password: "password123") }

  describe "GET /admin/professionals/new" do
    it "redirects anonymous visitors to sign in" do
      get new_admin_professional_path

      expect(response).to redirect_to(new_user_session_path)
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
      }.not_to change(Professional, :count)
    end

    it "lets an admin create a professional" do
      sign_in admin

      expect {
        post admin_professionals_path, params: { professional: { name: "Richard" } }
      }.to change(Professional, :count).by(1)
    end
  end
end
