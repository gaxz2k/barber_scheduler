require 'rails_helper'

RSpec.describe BarbershopPhoto, type: :model do
  include ActiveJob::TestHelper

  def attach_image(photo, content_type: 'image/png', io: fixture_file_upload('barbershop.png', 'image/png').tempfile)
    photo.image.attach(
      io: io,
      filename: 'barbershop.png',
      content_type: content_type
    )
  end

  def build_photo(**attributes)
    photo = described_class.new(attributes)
    attach_image(photo)
    photo
  end

  def build_photos(count)
    Array.new(count) { |position| build_photo(active: true, position: position).tap(&:save!) }
  end

  def stored_photo
    build_photo(active: true, position: 0).tap(&:save!)
  end

  def blob_and_key(photo)
    blob = photo.image.blob
    [ blob, blob.key ]
  end

  def storage_state(blob, key)
    [ ActiveStorage::Blob.exists?(blob.id), ActiveStorage::Blob.service.exist?(key) ]
  end

  it 'requires an image' do
    photo = described_class.new
    photo.validate

    expect(photo.errors[:image]).to include('não pode ficar em branco')
  end

  it 'accepts supported image types' do
    photo = described_class.new
    attach_image(photo)

    expect(photo).to be_valid
  end

  it 'rejects non-image content types' do
    photo = described_class.new
    attach_image(photo, content_type: 'text/plain', io: StringIO.new('not an image'))
    photo.validate

    expect(photo.errors[:image]).to include('deve ser PNG, JPG ou WEBP')
  end

  it 'rejects a mislabeled text file' do
    photo = described_class.new
    attach_image(photo, content_type: 'image/png', io: StringIO.new('not an image'))
    photo.validate

    expect(photo.errors[:image]).to include('o conteúdo não corresponde a uma imagem PNG, JPG ou WEBP válida')
  end

  it 'rejects SVG uploads even when the content type is an image' do
    photo = described_class.new
    attach_image(photo, content_type: 'image/svg+xml', io: StringIO.new('<svg></svg>'))
    photo.validate

    expect(photo.errors[:image]).to include('deve ser PNG, JPG ou WEBP')
  end

  it 'limits the published gallery to six photos' do
    photos = build_photos(6)
    photo = build_photo(active: true)
    result = photo.tap(&:validate).errors[:active].include?('limite de 6 fotos') && photos.all?(&:persisted?)

    expect(result).to be(true)
  end

  it 'orders published photos by position and creation time' do
    later = build_photo(caption: 'Depois', active: true, position: 1)
    earlier = build_photo(caption: 'Antes', active: true, position: 0)
    inactive = build_photo(active: false, position: 2)
    [ later, earlier, inactive ].each(&:save!)

    expect(described_class.published.pluck(:caption)).to eq(%w[Antes Depois])
  end

  it 'purges the stored image when the photo is destroyed' do
    photo = stored_photo
    blob, key = blob_and_key(photo)
    photo.destroy!
    perform_enqueued_jobs

    expect(storage_state(blob, key)).to eq([ false, false ])
  end

  def replace_image(photo)
    attach_image(photo)
    photo.save!
    perform_enqueued_jobs
  end

  it 'purges the replaced image when a new one is uploaded' do
    photo = stored_photo
    old_blob, old_key = blob_and_key(photo)
    replace_image(photo)

    expect(storage_state(old_blob, old_key)).to eq([ false, false ])
  end
end
