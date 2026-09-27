class Professional < ApplicationRecord
  include TenantScoped
  apply_tenant_scope

  # A unicidade do nome é por barbearia, não global: duas barbearias podem ter
  # um "Gustavo" cada. Com `uniqueness: true` global, a segunda barbearia que
  # contratasse um profissional homônimo seria recusada por um motivo que não
  # existe para o cliente — e o erro apareceria como "Nome já está em uso" ao
  # cadastrar alguém, o que é um defeito de multi-tenant, não uma proteção.
  belongs_to :barbershop_unit, optional: true

  validates :name, presence: true, uniqueness: { scope: :barbershop_id }
  validates_tenant_associations :barbershop_unit
  has_many :appointments, dependent: :restrict_with_error

  # Os profissionais de uma unidade, mais os que não têm unidade — quem atende
  # em todas aparece em todas. Esconder dele de uma unidade seria inventar uma
  # restrição que ninguém cadastrou.
  def self.for_unit(barbershop_unit)
    return all if barbershop_unit.nil?

    where(barbershop_unit_id: [ barbershop_unit.id, nil ])
  end

  # A especialidade como o cliente vê, ou nil quando não foi informada — a view
  # esconde o campo nesse caso, em vez de deixar um separador órfão.
  def specialty_label
    specialty.presence
  end
end
