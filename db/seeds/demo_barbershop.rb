# Barbearia de demonstração.
#
# Não é seed de produção: é uma vitrine, com dados de exibição para mostrar a
# plataforma para possíveis clientes. Fica num arquivo separado do `db/seeds.rb`
# para que ninguém rode isso por accidento ao fazer setup de um ambiente real —
# é preciso chamá-lo de propósito.
#
#   bin/rails db:seed:demo
#
# Idempotente, como o seed principal: pode rodar quantas vezes for preciso sem
# duplicar nada.

demo = Barbershop.find_or_create_by!(slug: "barbearia-exemplo") do |shop|
  shop.name = "Studio Navalha"
  shop.tagline = "Barbearia"
  shop.address = "Rua das Flores, 120 · Centro · São Paulo · SP"
  shop.phone = "(11) 98888-1200"
  shop.whatsapp = "(11) 98888-1200"
  shop.timezone = "America/Sao_Paulo"
  shop.opening_hours = {
    "1" => [ "09:00", "19:00" ],
    "2" => [ "09:00", "19:00" ],
    "3" => [ "09:00", "19:00" ],
    "4" => [ "09:00", "19:00" ],
    "5" => [ "09:00", "19:00" ],
    "6" => [ "09:00", "13:00" ],
    "7" => []
  }
end

Current.barbershop = demo

professionals = [
  { name: "Rafael Borges", specialty: "Degradê e navalha" },
  { name: "Thiago Nunes", specialty: "Barba clássica" },
  { name: "Bruno Almeida", specialty: "Platinado e coloração" }
].freeze

services = [
  { name: "Corte social", duration_minutes: 30, price_cents: 6000 },
  { name: "Degradê premium", duration_minutes: 45, price_cents: 8000 },
  { name: "Barba completa", duration_minutes: 30, price_cents: 5000 },
  { name: "Corte + barba", duration_minutes: 60, price_cents: 11000 },
  { name: "Platinado", duration_minutes: 120, price_cents: 22000 }
].freeze

professionals.each do |attributes|
  professional = Professional.find_or_create_by!(name: attributes[:name], barbershop_id: demo.id)
  professional.update!(specialty: attributes[:specialty])
end

services.each do |attributes|
  # Os atributos vão na própria busca, e não num bloco depois. Com
  # `find_or_create_by!` os atributos do bloco são aplicados DEPOIS da
  # validação, então criar sem duração já falha — e o erro chega como
  # "Duration minutes não pode ficar em branco", que não aponta para o seed.
  #
  # O `barbershop_id` faz parte da chave de propósito: a barbearia demo e a
  # operacional têm serviços com o mesmo nome ("Corte", "Barba"), e buscar só
  # pelo nome acharia o serviço da outra e reescreveria o preço dela.
  Service.find_or_create_by!(name: attributes[:name], barbershop_id: demo.id) do |service|
    service.duration_minutes = attributes[:duration_minutes]
    service.price_cents = attributes[:price_cents]
  end
end

Rails.logger.info do
  "Demo: #{demo.name} (#{demo.slug}) — " \
    "#{Professional.count} profissionais, #{Service.count} serviços, #{BarbershopPhoto.count} fotos"
end
Rails.logger.info do
  "Acesso: http://#{demo.slug}.localhost:#{ENV.fetch('PORT', 3000)}"
end
