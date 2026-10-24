class CreateShopSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :shop_settings do |t|
      t.references :barbershop, null: false, foreign_key: true, index: { unique: true }
      t.boolean :online_booking_enabled, null: false, default: true
      t.text :online_booking_message

      t.timestamps
    end
  end
end
