# frozen_string_literal: true

# Matchers que contam dentro de uma barbearia.
#
# `expect { post ... }.to change(Professional, :count)` conta sobre o escopo
# padrão do model, e o escopo padrão lê Current. Depois de uma requisição, o
# RequestStore::Middleware já limpou Current — corretamente, para
# que a requisição seguinte não herde nada. O `change` então compara duas
# contagens ambas zero e passa ou falha por acaso.
#
# Estes matchers contam no escopo do tenant explícito, que não depende de
# Current estar de pé. O nome diz o que faz, e o tenant é um argumento, não uma
# dependência implícita de estado global.
RSpec::Matchers.define :change_tenant_count do |model_class, tenant, delta|
  chain :by do |expected|
    @expected = expected
  end

  match do |block|
    tenant ||= test_barbershop

    before = model_class.for_barbershop(tenant).count
    block.call
    after = model_class.for_barbershop(tenant).count

    @actual = after - before
    @expected ||= delta

    @actual == @expected
  end

  failure_message do
    "esperava que #{model_class.name} do tenant #{tenant.inspect} mude em " \
      "#{@expected}, mas mudou em #{@actual}"
  end

  failure_message_when_negated do
    "esperava que #{model_class.name} do tenant #{tenant.inspect} NÃO mudasse, " \
      "mas mudou em #{@actual}"
  end

  supports_block_expectations
end

RSpec::Matchers.define :not_change_tenant_count do |model_class, tenant = nil|
  match do |block|
    tenant ||= test_barbershop
    before = model_class.for_barbershop(tenant).count
    block.call
    @actual = model_class.for_barbershop(tenant).count - before

    @actual.zero?
  end

  failure_message do |_block|
    "esperava que #{model_class.name} do tenant #{tenant.inspect} não mudasse, " \
      "mas mudou em #{@actual}"
  end

  supports_block_expectations
end
