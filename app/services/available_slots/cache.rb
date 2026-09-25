module AvailableSlots
  class Cache
    CACHE_TTL = 5.minutes

    def self.fetch(...)
      new(...).fetch
    end

    def self.invalidate(professional:, date:, service:)
      new(professional: professional, date: date, service: service).invalidate
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

      return AvailableSlots::Calculator.new(
        professional: @professional,
        date: @date,
        service: @service
      ).call if current_date?

      key = cache_key
      cached = redis.get(key)
      return deserialize(cached) if cached

      version = redis.get(generation_key) || "0"
      slots = calculate_slots

      result = with_current_generation(key, version, slots)
      result.nil? ? slots : result
    end

    def invalidate
      return if current_date?

      redis.multi do |transaction|
        transaction.incr(generation_key)
        transaction.del(cache_key)
      end
    rescue Redis::BaseError, RedisClient::Error => error
      Rails.logger.warn("Available slots cache invalidation failed: #{error.class}")
      nil
    end

    private

    attr_reader :professional, :date, :service

    def with_current_generation(key, version, slots)
      redis.watch(generation_key) do
        current_version = redis.get(generation_key) || "0"

        if current_version == version
          transaction_result = redis.multi do |transaction|
            transaction.set(key, serialize(slots), ex: CACHE_TTL.in_seconds.to_i)
          end
          transaction_result ? slots : nil
        else
          redis.unwatch
          cached = redis.get(key)
          cached ? deserialize(cached) : nil
        end
      end
    end

    def calculate_slots
      AvailableSlots::Calculator.new(
        professional: professional,
        date: date,
        service: service
      ).call
    end

    def current_date?
      date.to_date == Date.current
    end

    def cache_key
      [
        "available-slots",
        professional.id,
        date.to_date,
        service.id,
        service.duration_minutes
      ].join(":")
    end

    def generation_key
      "#{cache_key}:generation"
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
