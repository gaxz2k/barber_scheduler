class CreateBarbershops < ActiveRecord::Migration[8.1]
  def change
    create_table :barbershops do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :tagline
      t.string :address
      t.string :phone
      t.string :whatsapp
      t.string :timezone, null: false, default: "America/Sao_Paulo"

      # Horário de funcionamento em JSON: { "mon" => ["09:00", "19:00"], ... }.
      # JSON evita uma coluna e uma migration por dia da semana, e deixa cada
      # barbearia editar o próprio horário sem deploy.
      t.jsonb :opening_hours, null: false, default: {}

      t.timestamps
    end

    add_index :barbershops, :slug, unique: true
  end
end
