class AddCollectCpfToShopSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_settings, :collect_cpf, :boolean, default: false, null: false
  end
end
