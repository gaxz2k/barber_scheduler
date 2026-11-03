# Pin npm packages by running ./bin/importmap

# Turbo Drive intercepta cliques em links e submits de formulário para trocar
# só o <body> via fetch, em vez de forçar o navegador a recarregar a página
# inteira — é o que torna a navegação "liso"/SPA-like. O gem "turbo-rails"
# (Gemfile) já estava presente, mas sem este pin do pacote JS a parte
# client-side nunca carregava, então todo clique continuava sendo um reload
# cheio. Pinamos aqui e importamos em app/javascript/application.js.
pin "@hotwired/turbo-rails", to: "@hotwired--turbo-rails.js" # @8.0.23
pin "@hotwired/turbo", to: "@hotwired--turbo.js" # @8.0.23
pin "@rails/actioncable/src", to: "@rails--actioncable--src.js" # @8.1.400

pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "application"
pin_all_from "app/javascript/controllers", under: "controllers"
