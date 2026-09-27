module Appointments
  class Scheduler
    def self.call(...)
      new(...).call
    end

    # `barbershop_unit:` é obrigatório, e não deduzido.
    #
    # Deduzir seria transformar "não informado" em "a principal" sem ninguém
    # pedir: o agendamento existe, a agenda aparece, e o cliente vai para uma
    # loja que ele não escolheu. Sem unidade explícita a chamada nem chega ao
    # banco — o `ArgumentError` do Ruby aparece antes de qualquer escrita, e é
    # melhor que um agendamento gravado no lugar errado.
    #
    # A unidade do profissional não é usada como fonte: o profissional pode
    # atender em várias unidades, e quem sabe onde o cliente vai é a escolha
    # dele, não o cadastro do profissional.
    def initialize(client:, professional:, service:, start_at:, barbershop_unit:, **_ignored)
      @client = client
      @professional = professional
      @service = service
      @start_at = start_at
      @barbershop_unit = barbershop_unit
    end

    def call
      return invalid_appointment("serviço é obrigatório") if @service.blank?
      return invalid_appointment("cliente é obrigatório") if @client.blank?
      return invalid_appointment("profissional é obrigatório") if @professional.blank?
      return invalid_appointment("unidade é obrigatória") if @barbershop_unit.blank?
      if @professional&.barbershop_unit.present? && @professional.barbershop_unit_id != @barbershop_unit.id
        return invalid_appointment("profissional não atende nesta unidade")
      end

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
        barbershop_unit: @barbershop_unit,
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
