class AddCustomerNoteToAppointments < ActiveRecord::Migration[8.1]
  def change
    add_column :appointments, :customer_note, :text
  end
end
