require 'rails_helper'

RSpec.describe 'confirmation token path filtering', type: :request do
  def confirmation_request
    env = Rack::MockRequest.env_for('/appointments/confirmation/sensitive-token')
    env['action_dispatch.redirect_filter'] = Rails.application.config.filter_redirect
    ActionDispatch::Request.new(env)
  end

  it 'redacts the confirmation token from the filtered request path' do
    expect(confirmation_request.filtered_path).to eq('/appointments/confirmation/[FILTERED]')
  end

  it 'redacts the confirmation token from redirect log locations' do
    response = ActionDispatch::Response.new
    response.request = confirmation_request
    response.location = 'http://www.example.com/appointments/confirmation/sensitive-token'

    expect(response.filtered_location).to eq('[FILTERED]')
  end
end
