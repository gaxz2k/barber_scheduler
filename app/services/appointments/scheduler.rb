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
      return invalid_appointment("horário é obrigatório") if @start_at.blank?
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

    private

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
