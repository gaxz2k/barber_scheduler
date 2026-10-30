class AddEmailAndCpfToClients < ActiveRecord::Migration[8.1]
  def change
    change_table :clients, bulk: true do |t|
      t.column :email, :string
      t.column :cpf, :string
    end
    # O CPF circula sem pontuação (só dígitos), igual ao telefone — a
    # unicidade por tenant evita dois clientes com o mesmo CPF na mesma
    # barbearia sem impedir o mesmo CPF em barbearias diferentes.
    add_index :clients, [ :barbershop_id, :cpf ], unique: true, where: "cpf IS NOT NULL",
              name: "index_clients_on_barbershop_id_and_cpf"
  end
end
