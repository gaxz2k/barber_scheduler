# Uma unidade é um recorte dentro de uma barbearia, não um tenant novo.
#
# A fronteira de isolamento continua sendo `barbershops`. A unidade tem slug
# único POR BARBEARIA — duas barbearias podem ter ambas a unidade "centro", e
# isso é o que prova que a fronteira não se moveu para cá.
class BarbershopUnit < ApplicationRecord
  include TenantScoped
  apply_tenant_scope

  belongs_to :barbershop

  has_many :professionals, dependent: :nullify

  validates :name, presence: true
  # Unique no escopo da barbearia, e não `unique: true` global: duas
  # barbearias podem ter ambas a unidade "centro", e tornar o slug global
  # transferiria a fronteira de isolamento do tenant para o slug.
  validates :slug, presence: true, uniqueness: { scope: :barbershop_id }
  validates :slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }

  before_validation :normalize_slug

  def to_param
    slug
  end

  class << self
    # A unidade do slug dentro da barbearia do contexto. Devolve nil quando o
    # slug não existe ali — inclusive quando ele existe em outra barbearia, que
    # é o caso que impede a homônima de vazar.
    def for_slug(slug)
      return nil if slug.blank?

      where(slug: slug.to_s).first
    end
  end

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize.presence || name.to_s.parameterize
  end
end
