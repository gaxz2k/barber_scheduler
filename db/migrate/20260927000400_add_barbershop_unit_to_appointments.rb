class AddBarbershopUnitToAppointments < ActiveRecord::Migration[8.1]
  # A unidade fica gravada no agendamento, e não deduzida do link.
  #
  # O link de confirmação chega por e-mail e pode ser aberto depois de o cliente
  # trocar de unidade no site. Se a unidade fosse lida do link, o agendamento
  # apareceria na unidade errada. Aqui ela é fato: foi naquela unidade que o
  # horário foi reservado.
  #
  # Coluna nullable, backfill a partir da unidade principal da barbearia, e só
  # então NOT NULL — nenhuma base com agendamentos pode quebrar aqui.
  def up
    add_reference :appointments, :barbershop_unit, null: true

    # Backfill: cada agendamento vai para a unidade de menor id da sua
    # barbearia, que a migration anterior criou como unidade principal.
    #
    # `UPDATE ... FROM` com a subquery no FROM, e não LATERAL: a forma simples
    # dá o mesmo resultado porque a subquery só depende de
    # `appointments.barbershop_id`, que a tabela alvo já tem.
    execute <<~SQL.squish
      UPDATE appointments a
      SET barbershop_unit_id = u.id
      FROM (
        SELECT DISTINCT ON (barbershop_id) id, barbershop_id
        FROM barbershop_units
        ORDER BY barbershop_id, id
      ) u
      WHERE a.barbershop_unit_id IS NULL
        AND u.barbershop_id = a.barbershop_id
    SQL

    # Um agendamento sem barbershop_id não tem unidade possível, e a coluna
    # vira NOT NULL só depois de o backfill — se sobrou linha órfã, a
    # migration falha aqui em vez de deixar um agendamento sem unidade em
    # silêncio.
    change_column_null :appointments, :barbershop_unit_id, false
  end

  def down
    remove_reference :appointments, :barbershop_unit
  end
end
