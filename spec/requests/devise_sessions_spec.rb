require "rails_helper"

RSpec.describe "Devise sessions", type: :request do
  it "renders visible labels for the email and password fields" do
    get new_user_session_path

    labels = CGI.unescapeHTML(response.body).scan(/<label for="(user_email|user_password)">([^<]+)</).to_h

    expect(labels).to eq("user_email" => "E-mail", "user_password" => "Senha")
  end

  # Sem `scope:` no form_with, os campos são enviados sem o prefixo `user[]`
  # que o Devise espera, e o login falha sempre com "E-mail ou senha
  # inválidos" mesmo com a senha certa — o formulário nunca autentica
  # ninguém. Este teste trava esse contrato.
  it "submits the email field namespaced under user[]" do
    get new_user_session_path

    expect(response.body).to include('name="user[email]"')
  end

  it "submits the password field namespaced under user[]" do
    get new_user_session_path

    expect(response.body).to include('name="user[password]"')
  end

  # O teste acima trava o markup; este trava o comportamento real — um POST
  # como o navegador envia de verdade, sem o atalho `sign_in` do Devise::Test
  # (que injeta a sessão direto e não passa pelo form_with, por isso o bug
  # de scope sobreviveu despercebido na suíte inteira).
  it "authenticates with the credentials the real form submits" do
    admin = create_admin_for

    post user_session_path, params: { user: { email: admin.email, password: "password123" } }

    expect(response).to redirect_to(admin_root_path)
  end
end
