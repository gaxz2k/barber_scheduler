require 'rails_helper'

RSpec.describe "Barbers", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123", admin: true) }
  let(:regular_user) { User.create!(email: "user@example.com", password: "password123") }

  describe "GET /barbers/new" do
    it "redirects anonymous visitors to sign in" do
      get new_barber_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects logged-in users who are not admin" do
      sign_in regular_user

      get new_barber_path

      expect(response).to redirect_to(appointments_path)
    end

    it "is accessible to admins" do
      sign_in admin

      get new_barber_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /barbers" do
    it "does not let a non-admin create a barber" do
      sign_in regular_user

      expect {
        post barbers_path, params: { barber: { name: "Corte do Zé" } }
      }.not_to change(Barber, :count)
    end

    it "lets an admin create a barber" do
      sign_in admin

      expect {
        post barbers_path, params: { barber: { name: "Corte do Zé" } }
      }.to change(Barber, :count).by(1)
    end
  end
end
