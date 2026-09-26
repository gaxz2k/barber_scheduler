require 'rails_helper'

# O limite de seis fotos publicadas era validado só em Rubi, numa contagem
# seguida de escrita. Duas requisições simultâneas podiam ler 5 e gravar 6, ou
# ler 6 e gravar 6, e a galeria passaria do limite sem que nenhuma validação
# percebesse. Estes exemplos exercitam o trigger do banco, que é a rede de
# segurança: a verificação roda dentro do mesmo statement, então a segunda
# inserção já enxerga a primeira.
RSpec.describe "BarbershopPhoto published limit at the database layer", type: :model do
  def attach_image(photo)
    photo.image.attach(
      io: fixture_file_upload('barbershop.png', 'image/png').tempfile,
      filename: 'barbershop.png',
      content_type: 'image/png'
    )
    photo
  end

  def create_active_photo(position)
    attach_image(BarbershopPhoto.new(active: true, position: position)).tap(&:save!)
  end

  def fill_gallery
    Array.new(BarbershopPhoto::MAX_PUBLISHED_PHOTOS) { |i| create_active_photo(i) }
  end

  def insert_bypassing_validation
    # insert_all de propósito: é o caminho que ignora published_gallery_limit e
    # por isso expõe a camada do banco. Um save! normal passaria pela validação
    # de Rubi e não provaria nada sobre o trigger.
    BarbershopPhoto.insert_all( # rubocop:disable Rails/SkipsModelValidations
      Array.new(4) do |i|
        { active: true, position: 100 + i, created_at: Time.current, updated_at: Time.current }
      end
    )
  end

  it 'rejects a seventh row inserted without running the model validation' do
    fill_gallery

    expect { insert_bypassing_validation }.to raise_error(ActiveRecord::StatementInvalid, /limite de 6 fotos/)
  end

  it 'still allows editing a caption while the gallery is full' do
    photo = fill_gallery.first

    expect { photo.update!(caption: 'Legenda nova') }.not_to raise_error
  end

  it 'persists the new caption while the gallery is full' do
    photo = fill_gallery.first
    photo.update!(caption: 'Legenda nova')

    expect(photo.reload.caption).to eq('Legenda nova')
  end

  it 'still allows reordering a published photo while the gallery is full' do
    photo = fill_gallery.first

    expect { photo.update!(position: 99) }.not_to raise_error
  end

  it 'persists the new position while the gallery is full' do
    photo = fill_gallery.first
    photo.update!(position: 99)

    expect(photo.reload.position).to eq(99)
  end

  it 'rejects activating an inactive photo while the gallery is full' do
    inactive = attach_image(BarbershopPhoto.new(active: false, position: 0)).tap(&:save!)
    fill_gallery

    # A validação de Rubi dispara antes do statement, então o que chega aqui é
    # RecordInvalid com a mensagem amigável, não o erro cru do trigger. O
    # trigger continua sendo a rede de segurança para a corrida, coberta pelo
    # exemplo de insert_bypassing_validation.
    expect { inactive.update!(active: true) }.to raise_error(ActiveRecord::RecordInvalid, /limite de 6 fotos/)
  end

  it 'keeps the inactive photo inactive after the rejection' do
    inactive = attach_image(BarbershopPhoto.new(active: false, position: 0)).tap(&:save!)
    fill_gallery
    inactive.update(active: true)

    expect(inactive.reload.active).to be(false)
  end

  it 'allows deactivating a photo to free a slot' do
    fill_gallery.last.update!(active: false)

    expect { create_active_photo(42) }.not_to raise_error
  end

  it 'keeps the gallery at the limit after freeing and reusing a slot' do
    fill_gallery.last.update!(active: false)
    create_active_photo(42)

    expect(BarbershopPhoto.published.count).to eq(BarbershopPhoto::MAX_PUBLISHED_PHOTOS)
  end

  it 'does not limit inactive rows' do
    Array.new(10) do |i|
      attach_image(BarbershopPhoto.new(active: false, position: i)).tap(&:save!)
    end

    expect(BarbershopPhoto.where(active: false).count).to eq(10)
  end

  it 'lets a photo keep its own slot when the gallery is full' do
    photo = fill_gallery.first

    # A linha já ocupa um slot: contar o próprio registro bloquearia a edição.
    expect { photo.update!(position: photo.position + 1) }.not_to raise_error
  end
end
