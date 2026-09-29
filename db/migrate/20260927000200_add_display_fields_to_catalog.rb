class AddDisplayFieldsToCatalog < ActiveRecord::Migration[8.1]
  # Preço e especialidade: sem eles a vitrine não mostra o que o cliente
  # realmente vê ao escolher o serviço e o profissional. `price_cents` em
  # centavos evita ponto flutuante, que é o que a regra de pagamento do projeto
  # já exige.
  #
  # Nullable de propósito: um serviço já cadastrado não tem preço, e exigir a
  # coluna agora quebraria a gravação dele. O que a vitrine faz é esconder o
  # serviço sem preço, não inventar um valor.
  def up
    add_column :services, :price_cents, :integer
    add_column :professionals, :specialty, :string
  end

  def down
    remove_column :professionals, :specialty
    remove_column :services, :price_cents
  end
end
