class Appointment < ApplicationRecord
  belongs_to :client
  belongs_to :barber
  belongs_to :service

  validates :start_at, :end_at, presence: true

  enum :status, { pending: 0, confirmed: 1, canceled: 2, completed: 3 }, default: :pending

  validate :start_at_cannot_be_in_the_past, on: :create
  validate :barber_is_available

  validate :cannot_cancel_completed_appointment, if: :status_changed?

  def confirm!
    update!(status: :confirmed)
  end

  def cancel!
    update!(status: :canceled)
  end

  private

  def start_at_cannot_be_in_the_past
    return if start_at.blank?

    errors.add(:start_at, "não pode ser no passado") if start_at < Time.current
  end

  def barber_is_available
    return if barber_id.blank? || start_at.blank? || end_at.blank?

    conflicting = Appointment
                  .where(barber_id: barber_id)
                  .where.not(id: id)
                  .where("start_at < ? AND end_at > ?", end_at, start_at)

    errors.add(:base, "barbeiro já possui um agendamento nesse horário") if conflicting.exists?
  end

  def cannot_cancel_completed_appointment
    if status_was == "completed" && canceled?
      errors.add(:status, "não pode cancelar um agendamento já concluído")
    end
  end
end
