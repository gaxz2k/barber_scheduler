class Appointment < ApplicationRecord
  belongs_to :client
  belongs_to :professional
  belongs_to :service

  has_secure_token :confirmation_token, length: 32, on: :create
  before_validation :set_confirmation_expiration, on: :create

  validates :start_at, :end_at, presence: true

  enum :status, { pending: 0, confirmed: 1, canceled: 2, completed: 3 }, default: :pending

  validate :start_at_cannot_be_in_the_past, on: :create
  validate :start_at_is_on_slot_grid
  validate :end_at_after_start_at
  validate :end_at_matches_service_duration
  validate :professional_is_available
  validate :cannot_cancel_completed_appointment, if: :status_changed?

  after_commit :invalidate_available_slots_cache, on: [ :create, :update, :destroy ],
                if: :availability_cache_invalidation_required?

  def confirmation_accessible?
    confirmation_token.present? && confirmation_expires_at.present? && confirmation_expires_at > Time.current &&
      !canceled? && !completed?
  end

  def confirm!
    update!(status: :confirmed)
  end

  def cancel!
    update!(status: :canceled)
  end

  def set_confirmation_expiration
    self.confirmation_expires_at ||= 48.hours.from_now
  end

  def invalidate_available_slots_cache
    appointments_for_cache_invalidation.each do |professional, service, date|
      AvailableSlots::Cache.invalidate(
        professional: professional,
        date: date,
        service: service
      )
    end
  rescue Redis::BaseError, RedisClient::Error => error
    Rails.logger.warn("Available slots cache invalidation failed: #{error.class}")
    nil
  end

  private

  def availability_cache_invalidation_required?
    destroyed? || saved_changes.keys.intersect?(%w[professional_id start_at end_at service_id status])
  end

  def appointments_for_cache_invalidation
    current_professional_id = professional_id
    current_service_id = service_id
    previous_professional_id = saved_changes["professional_id"]&.first || current_professional_id
    previous_service_id = saved_changes["service_id"]&.first || current_service_id
    current_start_at = start_at
    current_end_at = end_at
    previous_start_at = saved_changes["start_at"]&.first || current_start_at
    previous_end_at = saved_changes["end_at"]&.first || current_end_at

    current_records = cache_records_for(
      professional_id: current_professional_id,
      service_id: current_service_id,
      start_at: current_start_at,
      end_at: current_end_at
    )
    previous_records = cache_records_for(
      professional_id: previous_professional_id,
      service_id: previous_service_id,
      start_at: previous_start_at,
      end_at: previous_end_at
    )

    (current_records + previous_records).uniq
  end

  def cache_records_for(professional_id:, service_id:, start_at:, end_at:)
    professional = Professional.find_by(id: professional_id)
    service = Service.find_by(id: service_id)
    dates = [ start_at, end_at ].compact.map(&:to_date).uniq

    dates.filter_map do |date|
      [ professional, service, date ] if professional && service
    end
  end

  def changed_attribute?(attribute)
    saved_changes.key?(attribute)
  end

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
