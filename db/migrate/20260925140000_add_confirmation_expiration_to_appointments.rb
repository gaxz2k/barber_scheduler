class AddConfirmationExpirationToAppointments < ActiveRecord::Migration[8.1]
  def change
    add_column :appointments, :confirmation_expires_at, :datetime
  end
end
