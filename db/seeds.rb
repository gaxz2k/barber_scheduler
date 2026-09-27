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

# O expediente da unidade principal, pelo mesmo motivo do catálogo: sem ele a
# agenda do cliente vem vazia em qualquer dia, e a demonstração do subdomínio
# mostra uma barbearia que existe mas não atende.
#
# O `update` é idempotente e sobrescreve de propósito. O seed é a fonte da
# configuração de demonstração, e um expediente editado à mão no painel volta
# ao valor do seed no próximo `db:seed` — que é o comportamento esperado de um
# seed, e o motivo de a tela de unidades existir para quem quiser manter o
# próprio.
#
# Segunda a sábado, 08:00–19:00. Domingo fica de fora de propósito: é o dia em
# que a maioria fecha, e a agenda vazia no domingo é a resposta certa.
expediente_principal = (1..6).to_h { |dia| [ dia.to_s, { "open" => "08:00", "close" => "19:00" } ] }
unidade_principal = barbershop.unidades.order(:id).first
unidade_principal.update!(opening_hours: expediente_principal)

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
Rails.logger.info do
  "Unidade #{unidade_principal.name} (/#{unidade_principal.slug}): seg-sáb 08:00-19:00"
end

# A vitrine vem por último, e é a última coisa de propósito: os seeds
# independentes rodam primeiro, e a demonstração só faz sentido quando a base
# já tem as tabelas no estado final. `db:prepare` (migrations + seed) é o
# comando que levanta o projeto com a vitrine de pé.
load Rails.root.join("db/seeds/demo_barbershop.rb")
