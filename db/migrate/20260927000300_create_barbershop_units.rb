class CreateBarbershopUnits < ActiveRecord::Migration[8.1]
  # Unidades de uma barbearia. A coluna entra nullable, é backfilled a partir da
  # própria barbearia, e só depois vira NOT NULL — como na migration de tenant:
  # uma base com dados não pode quebrar aqui.
  def up
    create_table :barbershop_units do |t|
      t.references :barbershop, null: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :address
      t.string :phone
      t.string :whatsapp
      t.string :timezone
      t.jsonb :opening_hours, default: {}, null: false
      t.timestamps
    end

    add_index :barbershop_units, [ :barbershop_id, :slug ], unique: true

    # Cada barbearia ganha uma unidade principal, para que nenhum agendamento
    # existente fique sem unidade. O slug é derivado do nome da barbearia, e a
    # unicidade é por barbearia, então não há colisão entre barbearias.
    execute <<~SQL.squish
      INSERT INTO barbershop_units (barbershop_id, name, slug, address, phone, created_at, updated_at)
      SELECT b.id,
             COALESCE(NULLIF(b.name, ''), 'Unidade Principal'),
             COALESCE(NULLIF(b.slug, ''), 'principal'),
             b.address,
             b.phone,
             NOW(),
             NOW()
      FROM barbershops b
    SQL

    add_reference :professionals, :barbershop_unit, null: true

    change_column_null :barbershop_units, :barbershop_id, false
  end

  def down
    remove_reference :professionals, :barbershop_unit
    drop_table :barbershop_units
  end
end
