class Appointment < ApplicationRecord
  belongs_to :client
  belongs_to :professional
  belongs_to :service

  validates :start_at, :end_at, presence: true

  enum :status, { pending: 0, confirmed: 1, canceled: 2, completed: 3 }, default: :pending

  validate :start_at_cannot_be_in_the_past, on: :create
  validate :start_at_is_on_slot_grid
  validate :end_at_after_start_at
  validate :end_at_matches_service_duration
  validate :professional_is_available
  validate :cannot_cancel_completed_appointment, if: :status_changed?

  def confirm!
    update!(status: :confirmed)
  end

  def cancel!
    update!(status: :canceled)
  end

  private

  def start_at_is_on_slot_grid
    return if start_at.blank?

    errors.add(:start_at, "não está alinhado à grade de horários") unless Scheduling.valid_slot?(start_at)
  end

  def end_at_after_start_at
    return if start_at.blank? || end_at.blank?

    errors.add(:end_at, "deve ser depois do início") if end_at <= start_at
  end

  def end_at_matches_service_duration
    return if start_at.blank? || end_at.blank? || service.blank?

    expected_end_at = start_at + service.duration_minutes.minutes
    errors.add(:end_at, "deve corresponder à duração do serviço") unless end_at == expected_end_at
  end

  def start_at_cannot_be_in_the_past
    return if start_at.blank?

    errors.add(:start_at, "não pode ser no passado") if start_at < Time.current
  end

  def professional_is_available
    return if professional_id.blank? || start_at.blank? || end_at.blank?
    return if canceled? || completed?

    conflicting = Appointment
                  .where(professional_id: professional_id)
                  .where.not(id: id)
                  .where.not(status: [ :canceled, :completed ])
                  .where("start_at < ? AND end_at > ?", end_at, start_at)

    errors.add(:base, "profissional já possui um agendamento nesse horário") if conflicting.exists?
  end

  def cannot_cancel_completed_appointment
    if status_was == "completed" && canceled?
      errors.add(:status, "não pode cancelar um agendamento já concluído")
    end
  end
end
