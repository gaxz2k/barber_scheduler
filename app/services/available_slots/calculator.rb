module AvailableSlots
  class Calculator
    # `barbershop_unit` é quem tem o horário. O profissional continua sendo a
    # origem de quem atende; a unidade é a origem de quando atende. São coisas
    # diferentes: um profissional pode atender em mais de uma unidade, e cada
    # uma tem horário próprio.
    #
    # `extra_services` soma à duração do serviço principal. Um horário só é
    # oferecido quando TODOS os slots de 30 minutos que a soma ocupa estão
    # livres — oferecer um início sem checar o bloco inteiro deixaria o
    # cliente marcar um horário que colide com outro agendamento dez minutos
    # depois do início.
    def initialize(professional:, date:, service:, barbershop_unit: nil, extra_services: [])
      @professional = professional
      @date = date
      @service = service
      @extra_services = Array(extra_services).compact
      @barbershop_unit = barbershop_unit
    end

    def call
      return [] if @date.blank? || @service.blank? || @professional.blank?

      local_date = @date.in_time_zone
      return [] unless local_date

      # A janela vem do horário da unidade. Sem ela, o dia não tem slots: o
      # horário é o que a barbearia prometeu, e oferecer o dia inteiro para
      # quem não cadastrou expediente é oferecer algo que a loja não cumpre.
      window = OpeningWindow.for(@barbershop_unit)
      return [] unless window.open?(local_date)

      @opens_at, @closes_at = window.range_for(local_date)

      (@opens_at...@closes_at).step(Scheduling::SLOT_DURATION).select do |slot|
        slot >= Time.current && valid_slot_for_service?(slot) && available?(slot)
      end
    end

    private

    attr_reader :opens_at, :closes_at

    # O serviço precisa CABER inteiro na janela, não começar dentro dela: um
    # corte que começaria 18:30 e terminaria 19:00 está dentro, mas o mesmo
    # corte começando 19:00 acabaria 19:30 e a loja já fechou.
    def valid_slot_for_service?(slot)
      return false unless Scheduling.valid_slot?(slot)

      slot + total_duration <= closes_at
    end

    def available?(slot)
      end_at = slot + total_duration

      Appointment
        .where(professional_id: @professional.id)
        .where(status: [ :pending, :confirmed ])
        .where("start_at < ? AND end_at > ?", end_at, slot)
        .none?
    end

    # A duração que efetivamente reserva a agenda.
    #
    # Só arredonda para o múltiplo de 30 seguinte quando há serviços extras —
    # ver o comentário equivalente em `Appointment#total_duration_minutes`
    # para a razão de não arredondar o serviço único.
    def total_duration
      raw_minutes = ([ @service ] + @extra_services).sum { |item| item.duration_minutes.to_i }
      return raw_minutes.minutes if @extra_services.empty?

      Scheduling.round_up_to_slot(raw_minutes).minutes
    end
  end
end
