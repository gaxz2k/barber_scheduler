require 'rails_helper'

RSpec.describe "Admin::Services", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password123", admin: true) }
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:professional) { Professional.create!(name: "Profissional Teste") }
  let(:client) { Client.create!(name: "Cliente Teste", phone: "11999999999") }
  let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

  before { sign_in admin }

  # Captures the real SQL issued while the block runs, so the specs can assert on the
  # SELECT ... FOR UPDATE the controller must take instead of stubbing the call.
  def sql_statements
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      statements << payload[:sql] unless payload[:name] == "SCHEMA"
    end
    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  def change_duration_to(minutes)
    patch admin_service_path(service), params: { service: { duration_minutes: minutes } }
  end

  def rename_to(name)
    patch admin_service_path(service), params: { service: { name: name } }
  end

  def create_appointment!
    Appointment.create!(
      client: client,
      professional: professional,
      service: service,
      start_at: start_at,
      end_at: start_at + service.duration_minutes.minutes
    )
  end

  def duration_change_error
    "não pode ser alterado quando existem agendamentos"
  end

  describe "PATCH /admin/services/:id" do
    it "updates the duration when no appointment exists" do
      change_duration_to(45)

      expect(service.reload.duration_minutes).to eq(45)
    end

    it "redirects to the service index after a successful update" do
      change_duration_to(45)

      expect(response).to redirect_to(admin_services_path)
    end

    it "keeps the duration immutable when appointments already exist" do
      create_appointment!

      change_duration_to(45)

      expect(service.reload.duration_minutes).to eq(30)
    end

    it "explains the immutability rule when the duration change is rejected" do
      create_appointment!

      change_duration_to(45)

      expect(response.body).to include(duration_change_error)
    end

    it "takes a row lock when writing the new duration" do
      statements = sql_statements { change_duration_to(45) }
      # set_service reads the row once; with_lock must be the read that takes FOR UPDATE.
      service_reads = statements.grep(/FROM "services"/)

      expect(service_reads.last).to match(/FOR UPDATE/i)
    end

    it "locks the service row before issuing the update" do
      statements = sql_statements { change_duration_to(45) }
      service_reads = statements.grep(/FROM "services"/)
      update_index = statements.index { |sql| sql.start_with?("UPDATE \"services\"") }

      expect(statements.index(service_reads.last)).to be < update_index
    end

    it "lets an admin rename a service that already has appointments" do
      create_appointment!

      rename_to("Corte premium")

      expect(service.reload.name).to eq("Corte premium")
    end

    it "does not block a rename on the duration rule" do
      create_appointment!

      rename_to("Corte premium")

      expect(response).to redirect_to(admin_services_path)
    end
  end
end
