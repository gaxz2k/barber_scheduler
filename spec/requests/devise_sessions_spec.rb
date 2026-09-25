require "rails_helper"

RSpec.describe "Devise sessions", type: :request do
  it "renders visible labels for the email and password fields" do
    get new_user_session_path

    labels = CGI.unescapeHTML(response.body).scan(/<label for="(email|password)">([^<]+)</).to_h

    expect(labels).to eq("email" => "E-mail", "password" => "Senha")
  end
end
