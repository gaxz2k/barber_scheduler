require "rails_helper"

# A vitrine precisa ser aberta por quem não está na mesma rede.
#
# O tenant vem do subdomínio, e o subdomínio precisa de um nome que o navegador
# resolva. Numa máquina de desenvolvimento isso é `slug.localhost`, que todo
# navegador moderno aponta para 127.0.0.1. Pela internet não existe tal
# convenção: um túnel efêmero entrega um único hostname (`algo.trycloudflare.
# com`), que não aceita `slug.` na frente — o Cloudflare recusa com 403, e o
# resultado é um endereço que não abre.
#
# O caminho `/t/<slug>` é o desvio. Ele não substitui o subdomínio: continua
# opcional, explícito e montado apenas em desenvolvimento, porque um endereço
# que muda a cada execução não pode ser o jeito canônico de escolher a
# barbearia.
RSpec.describe "acesso à vitrine por caminho, sem subdomínio", type: :request do
  let(:barbearia) do
    Barbershop.create!(name: "Barbearia Caminho", slug: "caminho-#{SecureRandom.hex(4)}")
  end
  let(:unidade) { test_unit_for(barbearia) }
  let(:host) { { "HTTP_HOST" => tenant_host(barbearia) } }

  it "o caminho resolve a mesma barbearia que o subdomínio" do
    unidade
    get "/t/#{barbearia.slug}", headers: host

    expect(response.body).to include(barbearia.name)
  end

  it "o caminho da vitrine abre a demonstração" do
    vitrine = Barbershop.unscoped.find_by(slug: "barbearia-exemplo")
    skip "a vitrine não está semeada neste ambiente" if vitrine.nil?

    get "/t/barbearia-exemplo", headers: host

    expect(response.body).to include("Studio Navalha")
  end

  # O teste que segura o isolamento. Se `/t/…` recorresse ao host — ou ao
  # cookie anterior — quando o slug não existe, este exemplo viraria 200 com a
  # tela de outra barbearia.
  it "um slug inexistente responde 404, e não a vitrine" do
    get "/t/barbearia-que-nao-existe", headers: host

    expect(response).to have_http_status(:not_found)
  end

  # O que o cookie resolve: as páginas seguintes do caminho, que não têm slug.
  # A segunda requisição vai sem host de barbearia nenhuma, que é a situação
  # real dentro do túnel — um hostname só, sem subdomínio para resolver.
  it "o cookie leva o tenant para as páginas que não têm slug na URL" do
    get "/t/#{barbearia.slug}", headers: host

    get "/barbearia/unidades/#{unidade.slug}", headers: { "HTTP_HOST" => "localhost" }

    expect(response.body).to include(barbearia.name)
  end

  it "o caminho não é montado em produção" do
    # Um controller que checasse o ambiente por request responderia igual nos
    # dois casos; o que garante a ausência da rota é ela não ser desenhada.
    rotas_de_t = Rails.application.routes.routes.map { |r| r.path.spec.to_s }.grep(%r{\A/t/})

    # A rota existe fora de produção e some nela, então o conjunto é vazio ou
    # não, conforme o ambiente — e o exemplo é sobre a ausência em produção,
    # que é o que um deploy precisa ter.
    expect(rotas_de_t.empty?).to be(Rails.env.production?)
  end
end
