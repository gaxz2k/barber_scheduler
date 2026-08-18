require 'rails_helper'

RSpec.describe Appointment, type: :model do
  let(:barber) { Barber.create!(name: "Barbeiro Teste") }
  let(:client) { Client.create!(name: "Cliente Teste", phone: "123") }
  let(:service) { Service.create!(name: "Corte", duration_minutes: 30) }
  let(:start_at) { 1.day.from_now.change(hour: 10, min: 0) }

  it "is invalid when start_at is in the past on create" do
    appointment = described_class.new(barber: barber, client: client, service: service,
                                       start_at: 1.day.ago, end_at: 1.day.ago + 30.minutes)

    expect(appointment).not_to be_valid
    expect(appointment.errors[:start_at]).to include("não pode ser no passado")
  end

  it "is invalid when it overlaps another appointment for the same barber" do
    described_class.create!(barber: barber, client: client, service: service,
                         start_at: start_at, end_at: start_at + 30.minutes)

    overlapping = described_class.new(barber: barber, client: client, service: service,
                                   start_at: start_at + 15.minutes, end_at: start_at + 45.minutes)

    expect(overlapping).not_to be_valid
    expect(overlapping.errors[:base]).to include("barbeiro já possui um agendamento nesse horário")
  end

  it "cannot be canceled after being completed" do
    appointment = described_class.create!(barber: barber, client: client, service: service,
                                           start_at: start_at, end_at: start_at + 30.minutes,
                                           status: :completed)

    expect { appointment.cancel! }.to raise_error(ActiveRecord::RecordInvalid)
    expect(appointment.reload.status).to eq("completed")
  end
end
