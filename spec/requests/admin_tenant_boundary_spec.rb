# frozen_string_literal: true

require "rails_helper"

# O painel administrativo é filtrado por tenant em todas as tabelas de
# negócio, mas o usuário não é: `require_admin!` checava só a flag `admin`.
# Um admin da loja A que resolvesse a loja B via host ou cookie entrava no
# painel B e viajava os registros da B — a camada de modelo não segura, porque
# o próprio usuário não é tenant-scoped. Estes specs travam a fronteira.
RSpec.describe "Painel não atravessa tenant", type: :request do
  let!(:loja_a) { Barbershop.create!(name: "Loja A", timezone: "America/Sao_Paulo") }
  let!(:loja_b) { Barbershop.create!(name: "Loja B", timezone: "America/Sao_Paulo") }

  # O admin pertence à loja A, mas a requisição resolve a loja B.
  let!(:admin_da_a) do
    User.create!(email: "dono-a@loja-a.test", password: "Senha12345",
                 admin: true, barbershop_id: loja_a.id)
  end

  # A unidade principal é criada no `before_validation` de `Barbershop`, então
  # não há o que fazer aqui: o `Loja A` e o `Loja B` já nascem com uma unidade
  # cada, que é o que o painel e a agenda exigem.
  def entra_com_o_admin_da_loja_a
    post user_session_path, params: { user: { email: admin_da_a.email, password: "Senha12345" } }
  end

  describe "a loja resolvida é outra" do
    before { entra_com_o_admin_da_loja_a }

    it "não deixa o painel abrir" do
      get admin_root_path, headers: { host: tenant_host(loja_b) }
      expect(response).to have_http_status(:redirect)
    end

    it "não devolve o nome da outra loja em nenhum painel" do
      %w[/admin /admin/appointments /admin/professionals /admin/services].each do |caminho|
        get caminho, headers: { host: tenant_host(loja_b) }
        expect(response.body).not_to include(loja_b.name)
      end
    end
  end

  describe "a loja resolvida é a própria" do
    before { entra_com_o_admin_da_loja_a }

    it "deixa o admin trabalhar na sua própria loja" do
      get admin_root_path, headers: { host: tenant_host(loja_a) }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "usuário sem vínculo com a loja resolvida" do
    let!(:sem_vinculo) do
      User.create!(email: "sem-loja@avulso.test", password: "Senha12345", admin: true)
    end

    it "não entra em painel de loja nenhuma" do
      post user_session_path, params: { user: { email: sem_vinculo.email, password: "Senha12345" } }
      get admin_root_path, headers: { host: tenant_host(loja_a) }
      expect(response).to have_http_status(:redirect)
    end
  end
end
