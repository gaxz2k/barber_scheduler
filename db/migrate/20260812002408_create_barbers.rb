class CreateBarbers < ActiveRecord::Migration[8.1]
  def change
    create_table :barbers do |t|
      t.string :name

      t.timestamps
    end
  end
end
