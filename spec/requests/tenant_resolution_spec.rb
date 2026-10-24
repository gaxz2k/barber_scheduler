require "rails_helper"

# A borda da requisição: liga Current a partir do host e garante que ele não
# vaze para a requisição seguinte.
#
# Sem isto a aplicação responde 200 e não mostra nada — toda consulta escopada
# volta vazia porque Current nunca é preenchido. Os exemplos abaixo percorrem o
# ciclo real de request, com Host diferente em cada um, que é o caminho que o
# browser usa.
RSpec.describe "resolução de tenant por host", type: :request do
  # Cada exemplo monta as duas requisições e compara o que cada uma serviu;
  # dividir em exemplos de uma expectativa só faria cada um passar sozinho.
  # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
  # O host de teste é o subdomínio sob `example.com`, que é o root host do
  # ambiente de teste (ver SubdomainResolver::TEST_ROOT_HOST).
  let!(:barbearia) { Barbershop.create!(name: "Barbearia Exemplo", slug: "exemplo") }

  # O serviço é criado em `before` e não em `let!` porque o `let!` roda antes do
  # `before` global que liga Current, e a validação de TenantScoped recusa
  # gravar sem contexto. Nenhum exemplo referencia o serviço pelo nome: o que
  # eles verificam é se ele aparece na página.
  before do
    within_tenant(barbearia) { Service.create!(name: "Corte Exemplo", duration_minutes: 30) }
  end

  after { Current.reset }

  it "serve os dados da barbearia do subdomínio" do
    get root_path, headers: { "HOST" => "exemplo.example.com" }

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Corte Exemplo")
  end

  it "devolve 404 para um subdomínio que não existe" do
    get root_path, headers: { "HOST" => "inexistente.example.com" }

    # 404 e não redirect: um host desconhecido não é uma barreira, é a ausência
    # de alguém. Um aviso ou um fallback revelaria que existe uma plataforma
    # com outras barbearias.
    expect(response).to have_http_status(:not_found)
  end

  it "não vaza o tenant de uma requisição para a seguinte" do
    get root_path, headers: { "HOST" => "exemplo.example.com" }
    primeiro = response.body

    get root_path, headers: { "HOST" => "outra.example.com" }

    # A segunda requisição é de outra barbearia (que nem existe) e não pode
    # enxergar o catálogo da primeira.
    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include("Corte Exemplo")
    expect(primeiro).to include("Corte Exemplo")
  end

  it "não serve uma barbearia quando o host é a raiz" do
    get root_path, headers: { "HOST" => "example.com" }

    expect(response).to have_http_status(:not_found)
  end

  it "lê o catálogo da barbearia certa quando existem duas" do
    outra = Barbershop.create!(name: "Outra Barbearia", slug: "outra")
    within_tenant(outra) do
      Service.create!(name: "Platinado Outro", duration_minutes: 120)
    end

    get root_path, headers: { "HOST" => "exemplo.example.com" }

    expect(response.body).to include("Corte Exemplo")
    expect(response.body).not_to include("Platinado Outro")
  end
end
# rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength
