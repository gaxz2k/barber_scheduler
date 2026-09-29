class AddBarbershopToTenantModels < ActiveRecord::Migration[8.1]
  # Multi-tenant: todo dado de operação passa a pertencer a uma barbearia.
  #
  # A coluna entra como nullable e só fica NOT NULL no fim, depois que a
  # barbearia de backfill é criada. Fazer NOT NULL de uma vez quebraria qualquer
  # base que já tenha dados, que é justamente o caso da de desenvolvimento.
  def up
    add_reference :clients, :barbershop, null: true
    add_reference :professionals, :barbershop, null: true
    add_reference :services, :barbershop, null: true
    add_reference :appointments, :barbershop, null: true
    add_reference :barbershop_photos, :barbershop, null: true
    add_reference :users, :barbershop, null: true

    backfill_legacy_barbershop

    change_column_null :clients, :barbershop_id, false
    change_column_null :professionals, :barbershop_id, false
    change_column_null :services, :barbershop_id, false
    change_column_null :appointments, :barbershop_id, false
    change_column_null :barbershop_photos, :barbershop_id, false

    # users fica nullable de propósito: um usuário sem barbearia é o caminho
    # para o signup público e para o bootstrap da primeira barbearia.
    #
    # IMPORTANTE: nada ainda usa esta coluna. `User` não é TenantScoped, não tem
    # associação `barbershop` e `AdminAuthorization` só chama `current_user.admin?`
    # — hoje um admin sem barbershop_id entra em /admin normalmente. O
    # "um usuário pertence a uma barbearia" é uma decisão de projeto, não um
    # invariante aplicado; quem vai aplicá-lo é a camada de request, com a
    # validação de current_user.barbershop == Current.barbershop.
    #
    # add_reference já cria o índice, então não há add_index aqui.
  end

  def down
    remove_reference :users, :barbershop
    remove_reference :barbershop_photos, :barbershop
    remove_reference :appointments, :barbershop
    remove_reference :services, :barbershop
    remove_reference :professionals, :barbershop
    remove_reference :clients, :barbershop

    # O `up` trocou a unicidade global de Professional.name pela unicidade por
    # barbearia, e removeu o índice antigo. O rollback tem que trazê-lo de volta:
    # sem esta linha, `remove_reference` derrubaria o índice composto junto e a
    # base ficaria sem nenhuma unicidade de nome — um rollback silenciosamente
    # mais permissivo que o estado anterior.
    add_index :professionals, :name, unique: true
  end

  private

  # Uma base que já tinha dados herda tudo de uma única barbearia, criada aqui
  # com o nome que o projeto usava antes do multi-tenant. Preserva o que
  # existe em vez de exigir um seed de migração.
  #
  # A unicidade de Professional.name deixa de ser global e passa a ser por
  # barbearia: duas barbearias podem ter um "Gustavo" cada, e o índice antigo
  # precisa sair antes do novo entrar.
  def backfill_legacy_barbershop
    legacy = Barbershop.create!(
      name: "Barbearia Senhor R",
      slug: "senhor-r",
      timezone: "America/Sao_Paulo"
    )

    [ :clients, :professionals, :services, :appointments, :barbershop_photos, :users ].each do |table|
      execute <<~SQL.squish
        UPDATE #{table} SET barbershop_id = #{legacy.id} WHERE barbershop_id IS NULL
      SQL
    end

    remove_index :professionals, :name
    add_index :professionals, [ :barbershop_id, :name ], unique: true
  end
end
