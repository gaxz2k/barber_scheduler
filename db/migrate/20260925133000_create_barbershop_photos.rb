class CreateBarbershopPhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :barbershop_photos do |t|
      t.string :caption
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :barbershop_photos, [ :active, :position ]
  end
end
