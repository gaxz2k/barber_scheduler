class Service < ApplicationRecord
  validates :name, :duration_minutes, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validate :duration_cannot_change_with_appointments
  has_many :appointments, dependent: :restrict_with_error

  private

  def duration_cannot_change_with_appointments
    return unless persisted? && will_save_change_to_duration_minutes? && appointments.exists?

    errors.add(:duration_minutes, "não pode ser alterado quando existem agendamentos")
  end
end
