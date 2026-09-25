class AddAppointmentScheduleConstraints < ActiveRecord::Migration[8.1]
  def up
    enable_extension "btree_gist" unless connection.extension_enabled?("btree_gist")

    add_check_constraint :appointments, "end_at > start_at", name: "appointments_end_after_start"

    execute <<~SQL.squish
      ALTER TABLE appointments
      ADD CONSTRAINT appointments_no_active_overlap
      EXCLUDE USING gist (
        professional_id WITH =,
        tsrange(start_at, end_at, '[)') WITH &&
      )
      WHERE (status IN (0, 1))
    SQL
  end

  def down
    execute "ALTER TABLE appointments DROP CONSTRAINT IF EXISTS appointments_no_active_overlap"
    remove_check_constraint :appointments, name: "appointments_end_after_start"
  end
end
