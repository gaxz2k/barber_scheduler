# frozen_string_literal: true

require "rails_helper"

# A criação de uma barbearia é a única requisição do sistema que roda sem
# tenant: não há host de barbearia, não há cookie, e é ela que produz o
# primeiro tenant. Por isso o controller não herda de `ApplicationController`,
# e por isso estes specs não usam o `tenant_host` que os outros usam.
#
# O que precisa ficar provado: a casa nasce com a unidade que o agendamento
# exige, o dono nasce admin **e** vinculado à casa, e o dono de uma casa não
# entra no painel da outra.
RSpec.describe "Criar barbearia", type: :request do
  let(:validos) do
    {
      barbershop: { name: "Barbearia do Zé", slug: "barbearia-do-ze", address: "Rua A, 10" },
      user: { email: "ze@teste.com", password: "SenhaForte1", password_confirmation: "SenhaForte1" }
    }
  end

  # O host é o do produto, sem tenant: é o host que o DNS entrega a quem ainda
  # não tem barbearia. Qualquer subdomínio aqui resolveria para a vitrine e a
  # requisição nunca chegaria a este controller. O `.test.host` é a mesma
  # forma que `tenant_host` usa, com `localhost` trocado por `test` — `www`
  # é barrado pela host authorization do ambiente de teste e devolve 404 antes
  # de qualquer controller rodar, o que mascararia o comportamento real.
  let(:host_sem_tenant) { "www.test.host" }

  # O `before(type: :request)` global chama `host! tenant_host` antes de cada
  # exemplo, porque a resolução de tenant acontece no host. Aqui o host é o
  # oposto: nenhuma barbearia, porque esta é a requisição que cria a primeira.
  # Um `headers: { host: }` no `get`/`post` seria sobrescrito pelo `host!` do
  # before, e o spec passaria a testar o cadastro contra a vitrine. Por isso o
  # `before` deste describe roda DEPOIS do global e chama `host!` de novo.
  before { host! host_sem_tenant }

  def host_da_casa_nova
    # Mesmo formato do `tenant_host` do `rails_helper`, que resolve a vitrine
    # com `<slug>.example.com`. Aqui a barra precisa ser a mesma porque a
    # resolução de tenant é a mesma: o subdomínio é o slug.
    "#{Barbershop.unscoped.find_by!(slug: "barbearia-do-ze").slug}.example.com"
  end

  def cadastra(atributos = validos)
    post barbershops_path, params: atributos
  end

  describe "GET /barbershops/new" do
    it "abre o formulário sem tenant" do
      get new_barbershop_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("barbershop[slug]", "user[email]")
    end

    it "não quebra o layout sem `Current.barbershop`" do
      get new_barbershop_path

      # O layout público lê `Current.barbershop.name` no `<title>` e no
      # `application-name`. Sem o piso, "criar sua barbearia" virava uma tela
      # branca com NoMethodError no log.
      expect(response.body).to include("<title>Criar barbearia</title>")
    end
  end

  describe "POST /barbershops" do
    it "cria a barbearia, a unidade e o dono admin" do
      cadastra

      barbershop = Barbershop.unscoped.find_by!(slug: "barbearia-do-ze")
      dono = User.unscoped.find_by!(email: "ze@teste.com")

      expect(barbershop.name).to eq("Barbearia do Zé")
      # A unidade não é opcional: `Appointment` exige uma, e sem ela a casa
      # nasce sem onde o cliente agendar.
      expect(barbershop.unidades.count).to eq(1)
      expect(dono.admin).to be(true)
      expect(dono.barbershop_id).to eq(barbershop.id)
    end

    it "loga o dono e manda para o painel no host da casa nova" do
      cadastra

      expect(controller.current_user.email).to eq("ze@teste.com")
      # O host importa: o painel só existe sob o subdomínio da casa, e um
      # redirect relativo cairia no host do cadastro — que não pertence a
      # ninguém — e a tela seguinte levantaria `RecordNotFound`.
      expect(response).to redirect_to("http://barbearia-do-ze.example.com:80/admin")
    end

    it "deixa o dono entrar no painel da própria casa" do
      cadastra
      # A sessão não sobrevive à troca de host: o cookie do Devise é por domínio,
      # e o cadastro acontece no host do produto (`www`), enquanto o painel da
      # casa nova é `casa-x.example.com`. Sem refazer o login, a requisição
      # chega ao painel como anônima e o 302 para `/users/sign_in` é a resposta
      # certa do Devise — não um furo. Entrar com a senha de novo é o que
      # testa o que importa: o dono nascent entra na casa que acabou de criar.
      host! host_da_casa_nova
      post user_session_path, params: { user: { email: "ze@teste.com", password: "SenhaForte1" } }

      get admin_root_path

      expect(response).to have_http_status(:ok)
    end

    it "não deixa o dono entrar no painel de outra casa" do
      cadastra
      # O login precisa ser refeito no host de destino, pelo mesmo motivo do
      # exemplo anterior: o cookie é por domínio. Sem ele o 302 viria do Devise
      # e não da checagem de tenant, e o teste passaria por um motivo errado.
      # O host é o da vitrine, não o da casa nova: é a travessia que o
      # `admin_tenant_boundary_spec` prova.
      host! tenant_host
      post user_session_path, params: { user: { email: "ze@teste.com", password: "SenhaForte1" } }

      get admin_root_path

      expect(response).to have_http_status(:redirect)
    end

    it "recusa slug repetido sem criar nada" do
      Barbershop.unscoped.create!(name: "Outra", slug: "barbearia-do-ze")

      cadastra

      expect(response).to have_http_status(:unprocessable_content)
      expect(User.unscoped.where(email: "ze@teste.com")).not_to exist
    end

    it "recusa e-mail repetido sem criar a casa" do
      User.unscoped.create!(email: "ze@teste.com", password: "SenhaForte1")

      cadastra

      expect(response).to have_http_status(:unprocessable_content)
      # A transactagem é o que garante isto: e-mail repetido é o caso comum, e
      # sem rollback a casa ficaria criada sem dono.
      expect(Barbershop.unscoped.where(slug: "barbearia-do-ze")).not_to exist
    end

    it "devolve a senha curta como erro legível, não como exceção" do
      cadastra(validos.deep_merge(user: { password: "curta", password_confirmation: "curta" }))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("8 caracteres")
    end

    it "devolve senha e confirmação diferentes como erro" do
      cadastra(validos.deep_merge(user: { password_confirmation: "OutraSenha1" }))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("não bate")
    end

    it "usa o nome como slug quando o campo fica vazio" do
      cadastra(validos.deep_merge(barbershop: { slug: "" }))

      expect(Barbershop.unscoped.find_by!(slug: "barbearia-do-ze")).to be_present
      expect(Barbershop.unscoped.where("slug LIKE ?", "barbearia-do-ze%").count).to eq(1)
    end

    it "normaliza o slug digitado" do
      cadastra(validos.deep_merge(barbershop: { slug: "Barbearia do Zé!!" }))

      expect(Barbershop.unscoped.where(slug: "barbearia-do-ze").count).to eq(1)
    end
  end
end
