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

professionals.each do |name|
  Professional.find_or_create_by!(name: name)
end

services.each do |attributes|
  Service.find_or_create_by!(name: attributes[:name]) do |service|
    service.duration_minutes = attributes[:duration_minutes]
  end
end

Rails.logger.info do
  "Profissionais: #{Professional.count} (#{Professional.pluck(:name).sort.join(", ")})"
end
Rails.logger.info do
  "Serviços: #{Service.count} " \
    "(#{Service.order(:name).pluck(:name, :duration_minutes).map { |name, minutes| "#{name} #{minutes}min" }.join(", ")})"
end
