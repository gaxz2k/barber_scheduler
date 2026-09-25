class BackfillConfirmationExpiration < ActiveRecord::Migration[8.1]
  def up
    execute(<<~SQL.squish)
      UPDATE appointments
      SET confirmation_expires_at = LEAST(created_at + INTERVAL '48 hours', CURRENT_TIMESTAMP)
      WHERE confirmation_expires_at IS NULL
    SQL

    change_column_null :appointments, :confirmation_expires_at, false
  end

  def down
    change_column_null :appointments, :confirmation_expires_at, true
  end
end
