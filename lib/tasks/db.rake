namespace :db do
  namespace :seed do
    desc "Recarrega só a barbearia modelo (a vitrine), sem tocar no seed principal"
    task demo: :environment do
      # O mesmo arquivo que `db/seeds.rb` carrega por último. Recarregar a
      # vitrine não reinicia a barbearia operacional: o seed é idempotente e
      # cada `find_or_*` acha o que já existe.
      load Rails.root.join("db/seeds/demo_barbershop.rb")
    end
  end
end
