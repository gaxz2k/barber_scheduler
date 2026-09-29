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

  # A foto do profissional, guardada como o `signed_id` do blob do Active
  # Storage, e não como um upload anexo.
  #
  # A diferença importa: `has_one_attached` cria a associação, a validação e a
  # leitura, e a coluna vira um `blob_id` com foreign key. O `signed_id` é uma
  # string, o Active Storage resolve em runtime, e a imagem some junto com o
  # registro sem `purge_later` — o que é a diferença real aqui: a foto do
  # profissional é um dado opcional e descartável, e manter a tabela de
  # attachments synchronized para ele só criaria um registro de blob por
  # profissional sem nenhum ganho.
  #
  # O mesmo caminho já é usado em `Barbershop#logo`.
  def photo_blob
    return nil if photo.blank?

    ActiveStorage::Blob.find_signed(photo)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    # Um `signed_id` adulterado ou de uma imagem já removida é o mesmo caso de
    # "não tem foto": a tela mostra a inicial do nome. Levantar aqui derrubaria
    # a página de quem só queria ver a agenda.
    nil
  end

  def photo?
    photo.present?
  end

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
