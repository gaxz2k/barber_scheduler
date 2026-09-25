module Appointments
  class Scheduler
    def self.call(...)
      new(...).call
    end

    def initialize(client:, professional:, service:, start_at:, **_ignored)
      @client = client
      @professional = professional
      @service = service
      @start_at = start_at
    end

    def call
      return invalid_appointment("serviço é obrigatório") if @service.blank?
      return invalid_appointment("cliente é obrigatório") if @client.blank?
      return invalid_appointment("profissional é obrigatório") if @professional.blank?
      return invalid_appointment("horário é obrigatório") if @start_at.nil?
      return invalid_appointment("horário é inválido") unless supported_start_at_type?
      return invalid_appointment("horário é inválido") unless normalize_start_at!

      with_locked_service { schedule_appointment }
    end

    private

    # Serializes the duration read against Admin::ServicesController#update. with_lock reloads
    # the row under SELECT ... FOR UPDATE and holds it while the appointment is inserted, so
    # end_at always reflects the persisted duration. If a concurrent admin destroy removed the
    # row first, lock! raises RecordNotFound and we return a domain error instead of inserting
    # an appointment against a missing service.
    def with_locked_service
      return yield unless @service.persisted?

      begin
        @service.with_lock { yield }
      rescue ActiveRecord::RecordNotFound
        invalid_appointment("serviço não está mais disponível")
      end
    end

    def schedule_appointment
      return invalid_appointment("duração do serviço é inválida") unless valid_service_duration?

      appointment = Appointment.new(
        client: @client,
        professional: @professional,
        service: @service,
        start_at: @start_at,
        end_at: end_at
      )

      unless Scheduling.valid_slot?(@start_at)
        appointment.errors.add(:start_at, "não está alinhado à grade de horários")
        return appointment
      end

      appointment.save
      appointment
    end

    def supported_start_at_type?
      @start_at.is_a?(String) || @start_at.is_a?(Time) || @start_at.is_a?(ActiveSupport::TimeWithZone)
    end

    def normalize_start_at!
      return false unless supported_start_at_type?

      @start_at = @start_at.in_time_zone
      @start_at.present?
    rescue ArgumentError, TypeError
      @start_at = nil
      false
    end

    def invalid_appointment(message)
      Appointment.new.tap { |appointment| appointment.errors.add(:base, message) }
    end

    def valid_service_duration?
      @service.duration_minutes.is_a?(Integer) && @service.duration_minutes.positive?
    end

    def end_at
      @start_at.to_time + service_duration
    end

    def service_duration
      @service.duration_minutes.minutes
    end
  end
end
