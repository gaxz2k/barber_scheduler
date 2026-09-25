module Scheduling
  SLOT_DURATION = 30.minutes

  def self.valid_slot?(time)
    return false if time.blank?

    time.sec.zero? && time.usec.zero? && (time.min % SLOT_DURATION.in_minutes).zero?
  end
end
