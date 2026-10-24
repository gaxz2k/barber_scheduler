# Seeds da vitrine.
#
# Idempotentes de propósito: podem rodar quantas vezes forem preciso, em
# qualquer ambiente, sem duplicar nada. É o que permite usar
# `bin/rails db:prepare` e `bin/rails db:seed` em sequência, e é o que o
# procedimento de setup documenta no README.
#
# O seed é a vitrine, e só ela. Não existe mais um catálogo bootstrap de uma
# barbearia qualquer aqui: o nome de um cliente ficava impresso em `<title>`, no
# logo do painel, no cabeçalho das telas públicas e no manifesto do PWA, em nove
# arquivos, e a vitrine aparecia com a marca dele em todos. Cada casa nova é
# criada na hora por quem vai administrá-la, em `/barbershops/new`.

# A vitrine é o seed inteiro. Ela cria a única barbearia que `db:prepare` monta,
# e já termina registrando o que montou e se está pronta para atender — com o
# log, o aviso de `missing_setup` e a URL. Este arquivo não precisa repetir
# nada disso, e também não deve: um segundo lugar que loga o estado da vitrine é
# um lugar que passa a divergir quando a vitrine muda.
load Rails.root.join("db/seeds/demo_barbershop.rb")
