class BarbershopPhoto < ApplicationRecord
  MAX_PUBLISHED_PHOTOS = 6
  MAX_IMAGE_BYTES = 10.megabytes
  ALLOWED_IMAGE_TYPES = %w[image/png image/jpeg image/webp].freeze

  has_one_attached :image, dependent: :purge_later

  validates :image, presence: true
  validates :caption, length: { maximum: 140 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :image_must_be_an_image
  validate :published_gallery_limit

  scope :published, -> { where(active: true).order(:position, :created_at) }

  private

  def image_must_be_an_image
    return unless image.attached?

    unless ALLOWED_IMAGE_TYPES.include?(image.content_type)
      errors.add(:image, "deve ser PNG, JPG ou WEBP")
    end
    errors.add(:image, "deve ter no máximo 10 MB") if image.byte_size.to_i > MAX_IMAGE_BYTES

    if pending_image_change?
      validate_pending_image_magic
    else
      validate_persisted_image_magic
    end
  end

  def pending_image_change?
    attachment_changes["image"].present?
  end

  def validate_pending_image_magic
    io = pending_image_io
    return errors.add(:image, "não pôde ser lida") unless io

    validate_image_magic(io)
  rescue IOError, SystemCallError
    errors.add(:image, "não pôde ser lida")
  end

  def pending_image_io
    attachable = attachment_changes["image"]&.attachable
    return attachable[:io] || attachable["io"] if attachable.is_a?(Hash)
    return attachable.tempfile if attachable.respond_to?(:tempfile)
    return attachable.open if attachable.respond_to?(:open)
    attachable if attachable.respond_to?(:read)
  end

  def validate_persisted_image_magic
    image.blob.open { |io| validate_image_magic(io) }
  rescue ActiveStorage::FileNotFoundError, IOError, SystemCallError
    errors.add(:image, "não pôde ser lida")
  end

  def validate_image_magic(io)
    io.rewind
    detected_type = Marcel::Magic.by_magic(io)&.type
    return if ALLOWED_IMAGE_TYPES.include?(detected_type)

    errors.add(:image, "o conteúdo não corresponde a uma imagem PNG, JPG ou WEBP válida")
  ensure
    io.rewind
  end

  def published_gallery_limit
    return unless active? && (new_record? || will_save_change_to_active?)

    return if self.class.where(active: true).count < MAX_PUBLISHED_PHOTOS

    errors.add(:active, "limite de #{MAX_PUBLISHED_PHOTOS} fotos")
  end
end
