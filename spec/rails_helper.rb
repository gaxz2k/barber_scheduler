# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
require 'sidekiq/testing'
require 'factory_bot_rails'
require 'shoulda-matchers'
require 'mock_redis'

# Matchers de tenant e qualquer outro arquivo em spec/support.
Rails.root.glob('spec/support/**/*.rb').sort.each { |file| require file }

Sidekiq::Testing.fake!

# Contexto de tenant para os testes.
#
# Todo model com TenantScoped nasce ligado à barbearia de Current. Num request
# spec isso vem do host da requisição; num model spec não há requisição, e o
# registro ficaria órfã. Este módulo cria uma barbearia por exemplo e a liga em
# Current, para que os specs existentes continuem testando o que já testavam —
# `Professional.create!(name: "X")` segue funcionando — e passem a carregar
# também o vínculo com a barbearia.
#
# O reset no fim é obrigatório. Sem ele, a barbearia do exemplo anterior vaza
# para o seguinte, que é a forma mais sutil de um teste de isolamento passar
# errado.
module TenantTestHelpers
  # O slug é único por exemplo: o hook de limpeza roda no fim da suíte, não
  # entre exemplos, e um slug fixo esbarraria no índice único no segundo
  # exemplo.
  def test_barbershop
    @test_barbershop ||= Barbershop.create!(
      name: "Barbearia Teste",
      slug: "barbearia-teste-#{SecureRandom.hex(4)}"
    )
  end

  # Uma segunda barbearia, para os exemplos que provam o isolamento.
  def other_barbershop
    @other_barbershop ||= Barbershop.create!(
      name: "Outra Barbearia",
      slug: "outra-barbearia-#{SecureRandom.hex(4)}"
    )
  end

  def switch_tenant_to(barbershop)
    Current.barbershop = barbershop
  end

  # `Model.last` depois de uma requisição lê o escopo padrão, e o escopo padrão
  # depende de Current — que o RequestStore::Middleware já limpou. Estas leituras acontecem
  # dentro do tenant explicitamente, sem depender do estado global.
  def tenant_records(model_class, tenant = nil)
    model_class.for_barbershop(tenant || test_barbershop)
  end

  # Executa um bloco com Current ligada à barbearia, e restaura ao final. Para
  # quando o exemplo precisa *criar* registros depois de uma requisição, e não
  # apenas lê-los: a validação de TenantScoped olha Current, então só passar
  # `barbershop:` no new não basta.
  def within_tenant(barbershop = test_barbershop)
    anterior = Current.barbershop
    Current.barbershop = barbershop
    yield
  ensure
    Current.barbershop = anterior
  end

  # Cria um Appointment válido, já com a unidade da barbearia em contexto.
  #
  # Existe porque a unidade é obrigatória e vários specs montam uma agenda para
  # exercitar outra coisa — slots, duração, cache. Cada um deles declararia a
  # mesma unidade, e o que precisam provar não é a unidade.
  #
  # A unidade vem da barbearia que está em `Current`, e não de `test_barbershop`
  # fixo: o spec de isolamento cria duas barbearias e agenda na A, e usar a
  # unidade de `test_barbershop` faria a validação recusar o agendamento como
  # pertencente a outra barbearia.
  def create_test_appointment!(**attributes)
    alvo = Current.barbershop || test_barbershop
    within_tenant(alvo) do
      Appointment.create!(**attributes, barbershop_unit: attributes[:barbershop_unit] || test_unit_for(alvo))
    end
  end

  # A unidade principal de uma barbearia, memoizada por barbearia, já com um
  # expediente definido.
  #
  # O expediente 08:00–22:00 em todos os dias existe porque a disponibilidade
  # passou a depender do horário de funcionamento. Sem ele, todo spec que
  # verifica slots recebe uma agenda vazia e falha por um motivo que não é o
  # que está testando. A janela é larga de propósito: o que esses specs
  # precisam provar é duração, grade e conflito, e não o limite do expediente.
  #
  # A gravação acontece dentro de `within_tenant` porque a unidade é
  # tenant-scoped: lida fora do contexto, ela não aparece.
  def test_unit_for(barbershop)
    @test_units ||= {}
    @test_units[barbershop.id] ||= within_tenant(barbershop) do
      unit = barbershop.unidades.order(:id).first
      expediente = (0..6).to_h { |dia| [ dia.to_s, { "open" => "08:00", "close" => "22:00" } ] }
      unit.update!(opening_hours: expediente)
      unit
    end
  end

  # O host que a requisição deve usar para resolver a barbearia pelo subdomínio.
  def tenant_host(barbershop = test_barbershop)
    "#{barbershop.slug}.example.com"
  end
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include Shoulda::Matchers::ActiveRecord
  config.include TenantTestHelpers

  # Cada exemplo começa e termina com uma Current limpa. O contexto é montado
  # no before, e não no around, porque um `let` lazy roda dentro do exemplo e
  # já precisa de Current de pé para criar o registro.
  config.around do |example|
    Current.reset
    example.run
  ensure
    Current.reset
  end

  config.before do
    Current.barbershop = test_barbershop
  end

  # O host padrão das requisições de teste é o subdomínio da barbearia de
  # teste, e não `www.example.com`: a resolução de tenant acontece no host, e
  # `www.example.com` não tem subdomínio que identifique ninguém — todas as
  # requisições dariam 404. Configurar aqui é melhor do que passar o header em
  # cada spec, porque um request spec que esquece o header passa a falhar em vez
  # de silenciosamente testar contra a raiz.
  config.before(type: :request) do
    host! tenant_host
  end

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails uses metadata to mix in different behaviours to your tests,
  # for example enabling you to call `get` and `post` in request specs. e.g.:
  #
  #     RSpec.describe UsersController, type: :request do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/8-0/rspec-rails
  #
  # You can also infer these behaviours automatically by location, e.g.
  # /spec/models would pull in the same behaviour as `type: :model` but this
  # behaviour is considered legacy and will be removed in a future version.
  #
  # To enable this behaviour uncomment the line below.
  # config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!

  config.include Devise::Test::IntegrationHelpers, type: :request
  # arbitrary gems may also be filtered via: config.filter_gems_from_backtrace("gem name")

  # O layout usa vite_javascript_tag, que precisa do manifesto de
  # public/vite-test. Sem isso todo spec de request que renderiza o layout
  # quebra com "Vite Ruby can't find entrypoints/application.tsx".
  config.before(:suite) do
    manifest = Rails.public_path.join("vite-test/.vite/manifest.json")
    abort("\nFalta o manifesto do Vite para test. Rode: RAILS_ENV=test npm run build\n") unless File.exist?(manifest)
  end

  # Specs assume an empty database. Records created by `rails runner` probes or a
  # stale test run otherwise leak into counts and uniqueness assertions.
  config.before(:suite) do
    # Este hook faz DELETE em todas as tabelas, então só é seguro contra o banco
    # descartável de test. `RAILS_ENV=development bundle exec rspec` apagaria os
    # dados reais da barbearia, e um DATABASE_URL apontando para produção seria
    # pior. O guard de produção acima não cobre esse caso, porque Rails.env seria
    # "development" nos dois.
    unless Rails.env.test?
      abort("\nA suíte só pode rodar com RAILS_ENV=test (está em #{Rails.env}). " \
            "O hook de limpeza apaga todas as tabelas.\n")
    end

    tables = ActiveRecord::Base.connection.tables - %w[schema_migrations ar_internal_metadata]
    ActiveRecord::Base.connection.disable_referential_integrity do
      tables.each { |table| ActiveRecord::Base.connection.execute("DELETE FROM #{table}") }
    end
  end
end
