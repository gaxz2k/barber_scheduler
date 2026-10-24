class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  # O usuário é o único model que NÃO usa `TenantScoped`, e a razão é que ele é
  # quem resolve o tenant: filtrar a tabela de usuários pelo tenant que ainda
  # está sendo resolvido seria circular. O vínculo existe em `barbershop_id` e
  # quem faz a checagem é `atende_esta_barbershop?`, chamada pelo painel.
  belongs_to :barbershop, optional: true

  # Se o admin pertence à mesma barbearia que a requisição resolveu.
  #
  # A checagem é feita aqui, no model, e não no controller, porque o controller
  # só conhece a flag `admin` — `User` era o único model do painel sem
  # associação, e `require_admin!` conferia `admin?` sozinho. Um admin da loja A
  # que resolvesse a loja B pelo host entrava no painel B: as tabelas de
  # negócio estão escopadas por `Current`, mas a *decisão de entrar* não era.
  def atende_esta_barbershop?(barbershop)
    return true if barbershop.nil?

    barbershop_id.present? && barbershop_id == barbershop.id
  end
end
