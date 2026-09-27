# Seeds da Barbearia Senhor R.
#
# Idempotentes de propósito: podem rodar quantas vezes forem preciso, em
# qualquer ambiente, sem duplicar nada. É o que permite usar
# `bin/rails db:prepare` e `bin/rails db:seed` em sequência, e o que o
# procedimento de setup documenta no README.
#
# O catálogo é o mínimo para a barbearia operar: um cliente precisa poder
# escolher serviço e profissional sem cadastrar nada na mão. Todos os valores
# usam find_or_create_by! pelo nome, que é a chave natural dos dois modelos —
# Professional ainda valida unicidade de nome, e Service não deixa mudar a
# duração quando já tem agendamento, então o seed nunca sobrescreve dado de
# operação.

professionals = [
  "Gustavo",
  "Richard",
  "Marcus"
].freeze

services = [
  { name: "Corte", duration_minutes: 30 },
  { name: "Barba", duration_minutes: 30 },
  { name: "Corte + Barba", duration_minutes: 60 },
  { name: "Pigmentação", duration_minutes: 45 },
  { name: "Platinado", duration_minutes: 120 }
].freeze

# O seed é o bootstrap: ele cria a primeira barbearia e o catálogo dela. Os
# models com TenantScoped recusam gravar fora de uma requisição, porque em
# operação normal Current resolve a barbearia pelo host. Aqui não há host, então
# o seed declara a barbearia explicitamente e a liga em Current — é o uso
# legítimo de acesso global, e o mesmo caminho que a resolução do subdomínio
# vai usar.
barbershop = Barbershop.find_or_create_by!(slug: "senhor-r") do |shop|
  shop.name = "Barbearia Senhor R"
  shop.timezone = "America/Sao_Paulo"
end

Current.barbershop = barbershop

professionals.each do |name|
  Professional.find_or_create_by!(name: name, barbershop_id: barbershop.id)
end

services.each do |attributes|
  # Os atributos entram na busca, e não no bloco: com `find_or_create_by!` o
  # bloco só roda DEPOIS da validação, então criar sem duração falharia com
  # "Duration minutes não pode ficar em branco" — um erro que aponta para o
  # model e não para o seed.
  Service.find_or_create_by!(name: attributes[:name], barbershop_id: barbershop.id,
                             duration_minutes: attributes[:duration_minutes])
end

Rails.logger.info do
  "Barbearia: #{barbershop.name} (#{barbershop.slug})"
end
Rails.logger.info do
  "Profissionais: #{Professional.count} (#{Professional.pluck(:name).sort.join(", ")})"
end
Rails.logger.info do
  "Serviços: #{Service.count} " \
    "(#{Service.order(:name).pluck(:name, :duration_minutes).map { |name, minutes| "#{name} #{minutes}min" }.join(", ")})"
end
