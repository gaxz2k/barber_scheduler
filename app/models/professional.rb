class Professional < ApplicationRecord
  include TenantScoped
  apply_tenant_scope

  # A unicidade do nome é por barbearia, não global: duas barbearias podem ter
  # um "Gustavo" cada. Com `uniqueness: true` global, a segunda barbearia que
  # contratasse um profissional homônimo seria recusada por um motivo que não
  # existe para o cliente — e o erro apareceria como "Nome já está em uso" ao
  # cadastrar alguém, o que é um defeito de multi-tenant, não uma proteção.
  validates :name, presence: true, uniqueness: { scope: :barbershop_id }
  has_many :appointments, dependent: :restrict_with_error
end
