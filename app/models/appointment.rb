class Appointment < ApplicationRecord
  include TenantScoped
  apply_tenant_scope
  validates_tenant_associations :client, :professional, :service, :barbershop_unit

  belongs_to :barbershop_unit
  belongs_to :client
  belongs_to :professional
  belongs_to :service

  has_secure_token :confirmation_token, length: 32, on: :create
  before_validation :set_confirmation_expiration, on: :create

  validates :start_at, :end_at, presence: true

  # A agenda de uma unidade. Sem argumento devolve tudo da barbearia, que é o
  # que o painel usa; com argumento, só a unidade.
  def self.for_unit(barbershop_unit)
    return all if barbershop_unit.nil?

    where(barbershop_unit_id: barbershop_unit.id)
  end

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

  # `status` é uma String neste enum, e String#humanize não passa pelo I18n:
  # devolveria "Pending" mesmo com default_locale em pt-BR. As traduções ficam
  # em config/locales/pt-BR.yml, sob
  # activerecord.attributes.appointment.statuses, que é a chave que o Rails usa
  # para enums. O humanize fica de fallback para um status novo não traduzido.
  def status_label
    I18n.t(
      "activerecord.attributes.appointment.statuses.#{status}",
      count: 1,
      default: status.to_s.humanize
    )
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
    appointments_for_cache_invalidation.each do |professional, service, date, unit|
      AvailableSlots::Cache.invalidate(
        professional: professional,
        date: date,
        service: service,
        barbershop_unit: unit
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
    current_unit_id = barbershop_unit_id
    previous_unit_id = saved_changes["barbershop_unit_id"]&.first || current_unit_id

    current_records = cache_records_for(
      professional_id: current_professional_id,
      service_id: current_service_id,
      start_at: current_start_at,
      end_at: current_end_at,
      unit_id: current_unit_id
    )
    previous_records = cache_records_for(
      professional_id: previous_professional_id,
      service_id: previous_service_id,
      start_at: previous_start_at,
      end_at: previous_end_at,
      unit_id: previous_unit_id
    )

    (current_records + previous_records).uniq
  end

  # A unidade entra no registro porque ela faz parte da chave do cache. Sem
  # ela, a invalidação usaria a chave "sem-unidade" e nunca apagaria a agenda
  # que foi calculada para a unidade real — o cache ficaria velho para sempre
  # depois do primeiro agendamento.
  #
  # A unidade vem do agendamento, e não do profissional: um profissional pode
  # atender em duas unidades, e é a unidade do agendamento que define a agenda
  # que mudou. Quando o profissional mudou, invalida as duas unidades, porque
  # as duas podem ter agenda calculada para ele.
  def cache_records_for(professional_id:, service_id:, start_at:, end_at:, unit_id: barbershop_unit_id)
    professional = Professional.find_by(id: professional_id)
    service = Service.find_by(id: service_id)
    return [] unless professional && service

    units = units_for_invalidation(unit_id)
    dates = [ start_at, end_at ].compact.map(&:to_date).uniq

    dates.flat_map do |date|
      units.filter_map { |unit| [ professional, service, date, unit ] }
    end
  end

  def units_for_invalidation(unit_id)
    if unit_id.present?
      [ BarbershopUnit.find_by(id: unit_id) ].compact
    else
      BarbershopUnit.none
    end
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
