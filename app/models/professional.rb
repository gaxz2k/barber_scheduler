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

  # Upload de foto pelo painel admin. `photo_upload` é um atributo virtual —
  # a coluna real é `photo` (o `signed_id` do blob, ver comentário abaixo) —
  # porque o formulário não manda um `signed_id`, manda o arquivo em si.
  # `before_validation` (e não `before_save`) porque a conversão para blob
  # precisa acontecer antes de `photo_upload_must_be_a_valid_image` rodar:
  # ela lê o arquivo, então tem que estar disponível quando a validação olha.
  attr_accessor :photo_upload, :remove_photo

  ALLOWED_PHOTO_TYPES = %w[image/png image/jpeg image/webp].freeze
  MAX_PHOTO_BYTES = 5.megabytes

  validate :photo_upload_must_be_a_valid_image
  before_save :apply_photo_upload
  before_save :apply_photo_removal
  after_save :reset_photo_upload_state

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

  private

  # Sobe o arquivo como um blob novo e guarda só o `signed_id` na coluna
  # `photo`, do mesmo jeito que o seed de demonstração faz — o blob não fica
  # anexado a este registro via Active Storage, por isso não há `purge` aqui:
  # o blob anterior (se houver) fica órfão, o mesmo comportamento que já
  # existia para quem editava a coluna `photo` na mão.
  def apply_photo_upload
    return if photo_upload.blank?

    blob = ActiveStorage::Blob.create_and_upload!(
      io: photo_upload,
      filename: photo_upload.original_filename,
      content_type: photo_upload.content_type
    )
    self.photo = blob.signed_id
    # A flag (e não zerar `photo_upload` aqui) é o que permite
    # `apply_photo_removal`, que roda logo depois, saber que houve upload
    # neste mesmo save — zerar `photo_upload` antes apagaria essa informação
    # cedo demais e a remoção desfaria o upload que acabou de ser aplicado.
    @photo_uploaded_this_save = true
  end

  # `remove_photo` some da tela assim que o profissional não tem mais foto,
  # então o checkbox só é respeitado quando ele realmente chegou marcado —
  # sem o `present?`/`true` aqui, `remove_photo: \"0\"` (o valor que o
  # `check_box` manda quando desmarcado) apagaria a foto em todo submit.
  def apply_photo_removal
    return unless ActiveModel::Type::Boolean.new.cast(remove_photo)
    return if @photo_uploaded_this_save # upload novo venceu a remoção no mesmo submit

    self.photo = nil
  end

  # Objetos de upload (`ActionDispatch::Http::UploadedFile`) e a flag de
  # controle não fazem sentido sobreviver além do save que os consumiu — um
  # segundo `save` no mesmo objeto em memória (comum em specs, raro em
  # controllers que recarregam a cada request) não pode reaplicar o upload
  # antigo nem reabrir a janela que protege a remoção.
  def reset_photo_upload_state
    self.photo_upload = nil
    self.remove_photo = nil
    @photo_uploaded_this_save = nil
  end

  def photo_upload_must_be_a_valid_image
    return if photo_upload.blank?

    unless ALLOWED_PHOTO_TYPES.include?(photo_upload.content_type)
      errors.add(:photo_upload, "deve ser PNG, JPG ou WEBP")
      return
    end

    if photo_upload.size.to_i > MAX_PHOTO_BYTES
      errors.add(:photo_upload, "deve ter no máximo 5 MB")
      return
    end

    detected_type = Marcel::Magic.by_magic(photo_upload)&.type
    unless ALLOWED_PHOTO_TYPES.include?(detected_type)
      errors.add(:photo_upload, "o conteúdo não corresponde a uma imagem PNG, JPG ou WEBP válida")
    end
  ensure
    photo_upload.rewind if photo_upload.respond_to?(:rewind)
  end
end
