module AvailableSlots
  class Calculator
    def initialize(professional:, date:, service:)
      @professional = professional
      @date = date
      @service = service
    end

    def call
      return [] if @date.blank? || @service.blank? || @professional.blank?

      local_date = @date.in_time_zone
      return [] unless local_date

      start_of_day = local_date.beginning_of_day
      @end_of_day = local_date.end_of_day

      (start_of_day...@end_of_day).step(Scheduling::SLOT_DURATION).select do |slot|
        valid_slot_for_service?(slot) && available?(slot)
      end
    end

    private

    attr_reader :end_of_day

    def valid_slot_for_service?(slot)
      return false unless Scheduling.valid_slot?(slot)

      slot + @service.duration_minutes.minutes <= end_of_day
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
