# frozen_string_literal: true

require "redis"
require "connection_pool"

redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Rails.application.config.x.redis = Redis.new(url: redis_url)
Rails.application.config.x.redis_pool = ConnectionPool.new(
  size: ENV.fetch("RAILS_MAX_THREADS", 5)
) { Redis.new(url: redis_url) }
