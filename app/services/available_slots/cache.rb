module AvailableSlots
  class Cache
    CACHE_TTL = 5.minutes

    def self.fetch(...)
      new(...).fetch
    end

    def initialize(professional:, date:, service:)
      @professional = professional
      @date = date
      @service = service
    end

    def fetch
      raise ArgumentError, "professional is required" if @professional.blank?
      raise ArgumentError, "date is required" if @date.blank?
      raise ArgumentError, "service is required" if @service.blank?

      key = cache_key
      cached = redis.get(key)
      return deserialize(cached) if cached

      slots = AvailableSlots::Calculator.new(
        professional: @professional,
        date: @date,
        service: @service
      ).call
      redis.set(key, serialize(slots), ex: CACHE_TTL.in_seconds.to_i)
      slots
    end

    private

    attr_reader :professional, :date, :service

    def cache_key
      [
        "available-slots",
        professional.id,
        @date.to_date,
        service.id
      ].join(":")
    end

    def redis
      Rails.application.config.x.redis
    end

    def serialize(slots)
      JSON.generate(slots.map(&:iso8601))
    end

    def deserialize(value)
      JSON.parse(value).map { |slot| Time.zone.parse(slot) }
    end
  end
end
