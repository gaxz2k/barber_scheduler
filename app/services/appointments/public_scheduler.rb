module Appointments
  class PublicScheduler
    def self.call(...)
      new(...).call
    end

    def initialize(name:, phone:, professional:, service:, start_at:)
      @name = name.to_s.strip
      @phone = phone.to_s.gsub(/\D/, "")
      @professional = professional
      @service = service
      @start_at = start_at
    end

    def call
      return invalid_appointment("Informe seu nome e um telefone válido.") if @name.blank? || !valid_phone?

      return invalid_appointment("Serviço é obrigatório") if @service.blank?
      return invalid_appointment("Profissional é obrigatório") if @professional.blank?
      return invalid_appointment("Horário é obrigatório") if @start_at.blank?

      result = Client.transaction do
        client = Client.create!(name: @name, phone: @phone)
        result = Scheduler.call(
          client: client,
          professional: @professional,
          service: @service,
          start_at: @start_at
        )
        raise ActiveRecord::Rollback unless result.persisted?

        result
      end

      result || invalid_appointment("Escolha um horário disponível.")
    rescue ActiveRecord::ExclusionViolation
      invalid_appointment("Escolha outro horário disponível.")
    rescue ActiveRecord::RecordInvalid => error
      invalid_appointment(error.record.errors.full_messages.to_sentence)
    end

    private

    def invalid_appointment(message)
      Appointment.new.tap { |appointment| appointment.errors.add(:base, message) }
    end

    def valid_phone?
      @phone.match?(/\A\d{10,11}\z/)
    end
  end
end
