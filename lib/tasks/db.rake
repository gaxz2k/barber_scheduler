namespace :db do
  namespace :seed do
    desc "Cria a barbearia de demonstração, com catálogo para vitrine"
    task demo: :environment do
      load Rails.root.join("db/seeds/demo_barbershop.rb")
    end
  end
end
