class CreateAppointmentServices < ActiveRecord::Migration[8.1]
  def change
    create_table :appointment_services do |t|
      t.references :appointment, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true

      t.timestamps
    end

    add_index :appointment_services, [ :appointment_id, :service_id ], unique: true
  end
end
