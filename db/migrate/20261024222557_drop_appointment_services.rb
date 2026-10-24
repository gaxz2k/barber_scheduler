class DropAppointmentServices < ActiveRecord::Migration[8.1]
  def change
    drop_table :appointment_services do |t|
      t.bigint "appointment_id", null: false
      t.bigint "service_id", null: false
      t.timestamps

      t.index [ "appointment_id", "service_id" ], unique: true
      t.index [ "appointment_id" ]
      t.index [ "service_id" ]
    end
  end
end
