require 'rails_helper'

RSpec.describe 'Admin photo navigation', type: :request do
  let(:admin) { create_admin_for }

  it 'exposes photo management from the admin dashboard' do
    sign_in admin

    get admin_root_path

    expect(response.body).to include('Fotos da barbearia', admin_barbershop_photos_path)
  end
end
