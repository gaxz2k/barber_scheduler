require "securerandom"

class AddConfirmationTokenToAppointments < ActiveRecord::Migration[8.1]
  def up
    add_column :appointments, :confirmation_token, :string

    select_values("SELECT id FROM appointments WHERE confirmation_token IS NULL").each do |id|
      execute(
        "UPDATE appointments SET confirmation_token = #{connection.quote(SecureRandom.hex(16))} WHERE id = #{connection.quote(id)}"
      )
    end

    change_column_null :appointments, :confirmation_token, false
    add_index :appointments, :confirmation_token, unique: true
  end

  def down
    remove_index :appointments, :confirmation_token
    remove_column :appointments, :confirmation_token
  end
end
