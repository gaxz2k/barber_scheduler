class RenameBarbersToProfessionals < ActiveRecord::Migration[8.1]
  def change
    rename_table :barbers, :professionals
    rename_column :appointments, :barber_id, :professional_id
  end
end
