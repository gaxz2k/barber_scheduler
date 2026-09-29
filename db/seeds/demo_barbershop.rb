# A barbearia modelo — a vitrine que existe sempre que o projeto levanta.
#
# Esta é a demonstração da plataforma: uma barbearia fictícia e completa que
# mostra a aparência real do produto. Ela é criada junto com o resto do seed,
# então `bin/rails db:prepare` — migrations e seed — já a deixa de pé. Para
# recarregar só a vitrine:
#
#   bin/rails db:seed:demo
#
# Não é seed de produção e nunca vira dado operacional. Tudo aqui é
# idempotente, então rodar quantas vezes for preciso não duplica nada e não
# quebra quem já mexeu nos dados.
#
# ── O contrato da vitrine ────────────────────────────────────────────────────
# A vitrine é a referência visual do produto, e para continuar servindo a isso
# ela precisa:
#
#   1. estar sempre presente depois de `db:prepare`;
#   2. passar por `Barbershop#setup_complete?` — é a única prova de que uma
#      barbearia real, montada só com o que a plataforma oferece, chega ao
#      estado em que pode atender;
#   3. ter agenda real: unidades com expediente, profissionais e serviços
#      suficientes para o fluxo de agendamento ter o que oferecer;
#   4. mostrar o layout inteiro, com galeria, preços e mais de uma unidade,
#      para que qualquer mudança visual possa ser conferida contra ela.
#
# O item 2 é o que mais importa e o mais fácil de quebrar em silêncio. Um item
# novo em `missing_setup` sem dado correspondente aqui faria a vitrine nascer
# "não pronta", e ninguém perceberia até alguém olhar a tela. Ao mexer em
# qualquer coisa que renda `missing_setup`, mexe aqui no mesmo commit.

require Rails.root.join("db/seeds/support/demo_photo_factory")

# ── A barbearia ─────────────────────────────────────────────────────────────
#
# O nome é "Studio Navalha" e o slug é "barbearia-exemplo" porque a vitrine
# precisa parecer a barbearia de outro lugar, e não o registro de quem desenvolve.
# Endereço genérico e telefone na faixa 9 de São Paulo, que é reservada para
# ficção.
#
# O `tagline` fica vazio de propósito. A home imprime o tagline acima do nome,
# e o "Studio" do nome já diz o que a casa é — com "Barbearia" em cima, a marca
# virava "Barbearia / Studio Navalha", que é a forma genérica que o usuário
# pediu para tirar. Uma casa que quiser dizer outra coisa preenche o campo.
#
# O `find_or_create_by!` só roda o bloco na primeira vez, então trocar este
# `tagline` não limpa a base de quem já rodou o seed. É o comportamento certo
# para um seed idempotente: ele não sobrescreve dado de operação.
demo = Barbershop.find_or_create_by!(slug: "barbearia-exemplo") do |shop|
  shop.name = "Studio Navalha"
  shop.tagline = nil
  shop.address = "Rua das Flores, 120 · Centro · São Paulo · SP"
  shop.phone = "(11) 98888-1200"
  shop.whatsapp = "(11) 98888-1200"
  shop.timezone = "America/Sao_Paulo"
end

Current.barbershop = demo

# ── Unidades ────────────────────────────────────────────────────────────────
#
# Duas unidades, porque escolher a loja na URL é funcionalidade da plataforma:
# uma vitrine com uma unidade só não a demonstra. Cada uma com expediente
# próprio, que é o ponto inteiro de `opening_hours` por unidade.
unidades = [
  {
    slug: "centro",
    name: "Unidade Centro",
    address: "Rua das Flores, 120 · Centro · São Paulo · SP",
    telefone: "(11) 98888-1200",
    expediente: (1..6).to_h { |dia| [ dia.to_s, { "open" => "09:00", "close" => "19:00" } ] }
  },
  {
    slug: "jardim",
    name: "Unidade Jardim",
    address: "Av. das Acácias, 840 · Jardim · São Paulo · SP",
    telefone: "(11) 98888-8400",
    expediente: {
      "1" => { "open" => "10:00", "close" => "20:00" },
      "2" => { "open" => "10:00", "close" => "20:00" },
      "3" => { "open" => "10:00", "close" => "20:00" },
      "4" => { "open" => "10:00", "close" => "20:00" },
      "5" => { "open" => "10:00", "close" => "20:00" },
      "6" => { "open" => "09:00", "close" => "13:00" }
    }
  }
].freeze

unidades.each do |dados|
  unidade = demo.unidades.find_or_initialize_by(slug: dados[:slug])
  unidade.name = dados[:name]
  unidade.address = dados[:address]
  unidade.phone = dados[:telefone]
  unidade.opening_hours = dados[:expediente]
  unidade.save!
end

# A unidade principal nasce com o slug da própria barbearia, pelo `after_create`
# de `Barbershop`. A vitrine não a apaga: ela é o que aquele callback garante,
# e removê-la aqui esconderia uma regressão dele. Em vez disso ganha o mesmo
# expediente da Centro, para que a URL `/<slug da barbearia>` — a que o
# `README` documenta — tenha agenda.
principal = demo.unidades.find_by(slug: demo.slug) || demo.unidades.order(:id).first
principal&.update!(opening_hours: unidades.first[:expediente])

# ── Profissionais ───────────────────────────────────────────────────────────
#
# Cada um pertence a uma unidade, e a associação é gravada: `Professional.
# for_unit` devolve quem atende em todas as unidades além dos da unidade, e uma
# vitrine onde os quatro atendem em todo lugar não mostra a diferença.
profissionais = [
  { name: "Rafael Borges", specialty: "Degradê e navalha", unidade: "centro" },
  { name: "Thiago Nunes", specialty: "Barba clássica", unidade: "centro" },
  { name: "Bruno Almeida", specialty: "Platinado e coloração", unidade: "jardim" },
  { name: "Camila Duarte", specialty: "Corte e acabamento", unidade: "jardim" }
].freeze

profissionais.each_with_index do |dados, indice|
  unidade = demo.unidades.find_by!(slug: dados[:unidade])
  profissional = Professional.find_or_create_by!(name: dados[:name], barbershop_id: demo.id)
  profissional.update!(specialty: dados[:specialty], barbershop_unit: unidade)
  profissional.update!(photo: DemoShowcase.retrato_de(dados[:name], indice: indice))
end

# ── Serviços ────────────────────────────────────────────────────────────────
#
# A faixa de preço é o que mostra catálogo de verdade: `price_cents` preenchido
# vira "R$ 60,00" no card do cliente. As durações cobrem o que a grade de 30min
# consegue encaixar — 30, 45, 60 e 120.
servicos = [
  { name: "Corte social", duration_minutes: 30, price_cents: 6000 },
  { name: "Degradê premium", duration_minutes: 45, price_cents: 8000 },
  { name: "Barba completa", duration_minutes: 30, price_cents: 5000 },
  { name: "Corte + barba", duration_minutes: 60, price_cents: 11000 },
  { name: "Pigmentação", duration_minutes: 45, price_cents: 9500 },
  { name: "Platinado", duration_minutes: 120, price_cents: 22000 }
].freeze

servicos.each do |attributes|
  # A duração e o preço vão na busca, e não num `update!` depois. Com
  # `find_or_create_by!` os atributos do bloco só são aplicados DEPOIS da
  # validação, então criar sem duração falharia com "Duration minutes não pode
  # ficar em branco" — um erro que aponta para o model e não para o seed, que é
  # a mesma armadilha do `db/seeds.rb`.
  #
  # O preço na busca é o que torna a reexecução idempotente de verdade: se o
  # preço mudasse no seed, uma linha antiga com o preço anterior não casaria
  # com a busca e o seed criaria um segundo serviço com o mesmo nome.
  #
  # O `barbershop_id` faz parte da chave de propósito: a vitrine e a barbearia
  # operacional têm serviços com o mesmo nome, e buscar só pelo nome acharia o
  # da outra e reescreveria o preço dela.
  Service.find_or_create_by!(
    name: attributes[:name],
    barbershop_id: demo.id,
    duration_minutes: attributes[:duration_minutes],
    price_cents: attributes[:price_cents]
  )
end

# ── Galeria ─────────────────────────────────────────────────────────────────
#
# Seis fotos, o limite de `BarbershopPhoto::MAX_PUBLISHED_PHOTOS`. As imagens
# são geradas em código (`db/seeds/support/demo_photo_factory.rb`) e anexadas
# só quando a foto ainda não tem arquivo: reexecutar o seed não deve custar
# seis gerações de imagem, e o trigger de limite recusa a sétima foto
# publicada.
legendas = [
  "Espelho e luz natural do salão",
  "Detalhe da navalha e do escovão",
  "Piso de ladrilho da sala de espera",
  "Arco do espelho de parede",
  "Luminária sobre o balcão",
  "Acabamento em degradê"
].freeze

legendas.each_with_index do |legenda, indice|
  foto = BarbershopPhoto.find_or_initialize_by(position: indice, caption: legenda)
  next if foto.persisted? && foto.image.attached?

  buffer = DemoShowcase::PhotoFactory.gerar(indice: indice)
  foto.caption = legenda
  foto.position = indice
  foto.active = true
  foto.image.attach(
    io: StringIO.new(buffer),
    filename: "studio-navalha-#{indice + 1}.webp",
    content_type: "image/webp"
  )
  foto.save!
end

# ── Verificação ─────────────────────────────────────────────────────────────
#
# A vitrine só é útil se estiver pronta para atender, e isso é uma regra do
# modelo, não uma opinião. A verificação imprime o que falta em vez de
# levantar exceção: um seed que derruba o `db:prepare` por causa da vitrine
# derrubaria o projeto inteiro, e a vitrine é acessória. O operador vê o aviso
# no log, e o seed principal já rodou.
faltando = demo.missing_setup

if faltando.any?
  Rails.logger.warn do
    "Vitrine (#{demo.slug}) NÃO está pronta para atender: falta #{faltando.join(", ")}. " \
      "Sem isso a demonstração mostra uma barbearia que não consegue agendar."
  end
else
  Rails.logger.info do
    "Vitrine (#{demo.slug}): pronta para atender — " \
      "#{demo.unidades.count} unidades, " \
      "#{Professional.for_barbershop(demo).count} profissionais, " \
      "#{Service.for_barbershop(demo).count} serviços, " \
      "#{BarbershopPhoto.for_barbershop(demo).published.count} fotos"
  end
end

Rails.logger.info do
  "Vitrine: http://#{demo.slug}.localhost:#{ENV.fetch('PORT', '3000')}"
end
