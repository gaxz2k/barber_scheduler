class AppointmentService < ApplicationRecord
  belongs_to :appointment
  belongs_to :service

  validates :service_id, uniqueness: { scope: :appointment_id }
end
