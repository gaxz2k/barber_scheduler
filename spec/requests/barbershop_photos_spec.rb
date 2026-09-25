require 'cgi'
require 'rails_helper'

RSpec.describe 'Barbershop photos', type: :request do
  let(:admin) { User.create!(email: 'admin@example.com', password: 'password123', admin: true) }
  let(:regular_user) { User.create!(email: 'user@example.com', password: 'password123') }

  before do
    BarbershopPhoto.delete_all
  end

  def attach_photo(active: true, position: 0, caption: 'Ambiente')
    photo = BarbershopPhoto.new(active: active, position: position, caption: caption)
    photo.image.attach(
      io: fixture_file_upload('barbershop.png', 'image/png'),
      filename: 'barbershop.png',
      content_type: 'image/png'
    )
    photo.save!
    photo
  end

  def photo_attributes
    {
      image: fixture_file_upload('barbershop.png', 'image/png'),
      caption: 'Novo ambiente', active: '1', position: '2'
    }
  end

  def replacement_attributes
    { barbershop_photo: { image: fixture_file_upload('barbershop.png', 'image/png'), caption: 'Atualizada' } }
  end

  it 'shows only active photos in the public home carousel' do
    published = attach_photo(caption: 'Capa publicada', position: 0)
    unpublished = attach_photo(caption: 'Foto privada', position: 1, active: false)
    get root_path
    result = [ response.body.include?(published.caption), response.body.include?(unpublished.caption) ]

    expect(result).to eq([ true, false ])
  end

  def home_block_order
    Service.create!(name: "Barba", duration_minutes: 30)
    attach_photo
    get root_path
    html = CGI.unescapeHTML(response.body)
    main = html[/<main class="site-shell customer-home booking-entry">(.*)<\/main>/m, 1]
    [ main.index("barbershop-carousel"), main.index("booking-progress"), main.index("booking-intro") ]
  end

  it 'renders the carousel as the first content of the home' do
    order = home_block_order
    result = order.map { |index| !index.nil? } + [ order == order.sort ]

    expect(result).to eq([ true, true, true, true ])
  end

  it 'renders accessible carousel controls and image error states' do
    attach_photo
    get root_path
    result = CGI.unescapeHTML(response.body).scan(/data-barbershop-carousel-target="image"|data-barbershop-carousel-target="imageFallback"|barbershop-carousel__image-fallback|keydown->barbershop-carousel#keydown|focusin->barbershop-carousel#stop|focusout->barbershop-carousel#start|error->barbershop-carousel#imageError/).uniq

    expect(result).to include('data-barbershop-carousel-target="image"', 'data-barbershop-carousel-target="imageFallback"', 'barbershop-carousel__image-fallback', 'keydown->barbershop-carousel#keydown', 'focusin->barbershop-carousel#stop', 'focusout->barbershop-carousel#start', 'error->barbershop-carousel#imageError')
  end

  it 'renders a useful empty state when no photos are active' do
    get root_path

    expect(response.body).to include('Novas fotos em breve')
  end

  it 'rejects an invalid replacement without a server error' do
    sign_in admin
    photo = attach_photo

    patch admin_barbershop_photo_path(photo), params: invalid_replacement_attributes

    expect(response.status).to eq(422)
  end

  def invalid_replacement_attributes
    {
      barbershop_photo: {
        image: fixture_file_upload('barbershop.png', 'image/png'),
        caption: 'a' * 141
      }
    }
  end

  it 'protects the photo management page from non-admins' do
    sign_in regular_user

    get admin_barbershop_photos_path

    expect(response).to redirect_to(root_path)
  end

  it 'allows an admin to upload, order, and activate a photo' do
    sign_in admin
    post admin_barbershop_photos_path, params: { barbershop_photo: photo_attributes }
    photo = BarbershopPhoto.last
    result = [ photo.caption, photo.position, photo.active?, photo.image.attached?, response.redirect_url ]

    expect(result).to eq([ 'Novo ambiente', 2, true, true, admin_barbershop_photos_url ])
  end

  it 'replaces an existing image when the admin uploads a replacement' do
    sign_in admin
    photo = attach_photo
    patch admin_barbershop_photo_path(photo), params: replacement_attributes
    result = [ photo.reload.caption, photo.image.attached? ]

    expect(result).to eq([ 'Atualizada', true ])
  end

  it 'rejects bytes that are not an image without persisting the photo' do
    sign_in admin
    post admin_barbershop_photos_path, params: invalid_image_attributes('invalid.txt', 'image/png')
    result = [ response.status, BarbershopPhoto.count ]

    expect(result).to eq([ 422, 0 ])
  end

  it 'rejects SVG uploads without persisting the photo' do
    sign_in admin
    post admin_barbershop_photos_path, params: invalid_image_attributes('invalid.svg', 'image/svg+xml')
    result = [ response.status, BarbershopPhoto.count ]

    expect(result).to eq([ 422, 0 ])
  end

  def invalid_image_attributes(file, content_type)
    {
      barbershop_photo: {
        image: fixture_file_upload(file, content_type),
        active: '1',
        position: '1'
      }
    }
  end

  it 'allows an admin to deactivate a photo' do
    sign_in admin
    photo = attach_photo

    patch admin_barbershop_photo_path(photo), params: { barbershop_photo: { active: '0' } }

    expect(photo.reload).not_to be_active
  end
end
