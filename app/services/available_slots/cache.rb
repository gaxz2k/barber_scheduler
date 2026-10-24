module AvailableSlots
  class Cache
    CACHE_TTL = 5.minutes

    def self.fetch(...)
      new(...).fetch
    end

    def self.invalidate(professional:, date:, service:, barbershop_unit: nil, extra_services: [])
      new(
        professional: professional, date: date, service: service,
        barbershop_unit: barbershop_unit, extra_services: extra_services
      ).invalidate
    end

    def initialize(professional:, date:, service:, barbershop_unit: nil, extra_services: [])
      @professional = professional
      @date = date
      @service = service
      @extra_services = Array(extra_services).compact
      @barbershop_unit = barbershop_unit
    end

    def fetch
      raise ArgumentError, "professional is required" if @professional.blank?
      raise ArgumentError, "date is required" if @date.blank?
      raise ArgumentError, "service is required" if @service.blank?

      return calculate_slots if current_date?

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

    attr_reader :professional, :date, :service, :barbershop_unit, :extra_services

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
        service: service,
        barbershop_unit: barbershop_unit,
        extra_services: extra_services
      ).call
    end

    def current_date?
      date.to_date == Date.current
    end

    def cache_key
      [
        "available-slots",
        barbershop_unit&.id || "sem-unidade",
        professional.id,
        date.to_date,
        service.id,
        service.duration_minutes,
        extra_services_key
      ].join(":")
    end

    # Os ids dos extras, ordenados e deduplicados: a mesma combinação de
    # serviços extras tem de produzir a mesma chave independente da ordem em
    # que o cliente clicou nos botões "adicionar serviço".
    def extra_services_key
      extra_services.map(&:id).sort.join(",")
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
