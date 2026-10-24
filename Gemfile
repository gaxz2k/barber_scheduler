source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.4"
gem "pg"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use Redis for Rails.cache and Sidekiq for Active Job.
gem "redis", "~> 5.4"
gem "connection_pool"
gem "sidekiq", "~> 8.0"
# Solid Cable remains the Action Cable adapter for production cable storage.
gem "solid_cable"
gem "rails-i18n"
# Current attributes por requisição. Sem isso, o contexto de multi-tenant
# dependeria de uma variável global, que sobrevive entre requisições num
# processo de worker e serve a agenda da barbearia errada.
gem "request_store"


# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
#
# A partir da 2.x, image_processing parou de depender de um backend fixo —
# quem usa escolhe mini_magick OU vips. O projeto sempre rodou com vips (é o
# padrão do Rails 8 para variantes), então a dependência precisa ficar
# explícita aqui, senão o boot quebra com LoadError assim que algo chamar
# ImageProcessing::Vips.
gem "image_processing", "~> 2.2"
# `require: false`: a gem só é carregada quando algo de fato chama
# ImageProcessing::Vips, não no boot. Sem isso o Bundler.require tenta abrir
# a lib nativa libvips.so.42 em TODO job do CI — inclusive os que não
# instalam libvips (só o job `test` roda `apt-get install libvips`), e o
# boot quebra em scan_js/scan_ruby/lint com "cannot open shared object file".
gem "ruby-vips", "~> 2.0", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rspec-rails"
  gem "dotenv-rails"
  gem "mock_redis"
  gem "factory_bot_rails"
  gem "shoulda-matchers"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Cops para specs do RSpec [https://github.com/rubocop/rubocop-rspec]
  gem "rubocop-rspec", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end

gem "importmap-rails", "~> 2.2"

gem "devise", "~> 5.0"

gem "inertia_rails", "~> 3.23"
gem "vite_rails", "~> 3.11"
