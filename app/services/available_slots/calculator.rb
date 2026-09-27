module AvailableSlots
  class Calculator
    # `barbershop_unit` é quem tem o horário. O profissional continua sendo a
    # origem de quem atende; a unidade é a origem de quando atende. São coisas
    # diferentes: um profissional pode atender em mais de uma unidade, e cada
    # uma tem horário próprio.
    def initialize(professional:, date:, service:, barbershop_unit: nil)
      @professional = professional
      @date = date
      @service = service
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

      slot + @service.duration_minutes.minutes <= closes_at
    end

    def available?(slot)
      end_at = slot + @service.duration_minutes.minutes

      Appointment
        .where(professional_id: @professional.id)
        .where(status: [ :pending, :confirmed ])
        .where("start_at < ? AND end_at > ?", end_at, slot)
        .none?
    end
  end
end
