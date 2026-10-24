class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # A borda do tenant. Todo request passa por aqui, e é aqui que Current passa
  # a existir: sem isto, nenhuma query escopada devolve nada e a aplicação
  # responde 200 sem conteúdo.
  #
  # A resolução tem duas fontes, nesta ordem: o subdomínio e o cookie. O
  # subdomínio é o jeito canônico e o que vale em produção. O cookie existe
  # porque um host único não tem subdomínio para carregar o tenant — é o caso de
  # um túnel de demonstração, onde `slug.` na frente do hostname é recusado na
  # borda e o endereço não abre.
  #
  # O `ensure` existe para o caso de exceção dentro da requisição, e não
  # substitui o RequestStore: quem garante a limpeza no caminho normal é o
  # middleware, no fechamento do body. Os dois juntos cobrem os dois caminhos.
  around_action :use_current_barbershop
  before_action :remember_tenant_from_path

  # O nome do cookie fica aqui, e não espalhado em duas linhas de código: um
  # nome escrito duas vezes é um nome que alguém renomeia em um lugar só. O
  # cookie é de sessão (sem `expires`), e some quando o browser fecha.
  TENANT_COOKIE = "barbershop_tenant"

  protected

  def after_sign_in_path_for(resource)
    resource.admin? ? admin_root_path : root_path
  end

  # `/t/<slug>` é a entrada do desvio: resolve a barbearia e grava o cookie.
  # A partir daí é o navegador que leva o cookie em cada navegação, e não a URL
  # — que é o que faz a vitrine inteira funcionar, e não só a home.
  #
  # Por que cookie e não reescrita de host: `request.host=` não sobrevive à
  # resposta. A requisição seguinte volta com o host original, o resolver não
  # acha subdomínio, e a página responde 404. O caminho funcionaria uma vez e
  # nunca mais.
  def remember_tenant_from_path
    return unless tenant_from_path?

    barbershop = barbershop_from_path
    raise ActiveRecord::RecordNotFound if barbershop.nil?

    cookies.encrypted[TENANT_COOKIE] = {
      value: barbershop.slug,
      httponly: true,
      same_site: :lax
    }
  end

  private

  def use_current_barbershop
    Current.barbershop = resolve_tenant
    raise ActiveRecord::RecordNotFound if Current.barbershop.nil?

    yield
  ensure
    Current.reset
  end

  # A resolução do tenant, na ordem que impede um slug inválido de virar 200.
  #
  # Três fontes, e a ordem não é arbitrária:
  #
  # 1. `/t/<slug>` — quando a requisição É o desvio, o slug é a única resposta
  #    possível. Cair no host aqui transformaria `/t/barbearia-que-nao-existe`
  #    na tela de quem estivesse no host: a tela de uma barbearia por causa do
  #    slug de outra.
  # 2. Subdomínio — o jeito canônico, e o único que vale em produção.
  # 3. Cookie — só quando não há subdomínio, e só fora de produção, porque ele
  #    é gravado pela rota `/t/`, que não existe em produção.
  def resolve_tenant
    return barbershop_from_path if tenant_from_path?

    resolve_barbershop || barbershop_from_cookie
  end

  # Verdadeiro quando a requisição é o desvio `/t/<slug>`, e não a home pelo
  # subdomínio.
  def tenant_from_path?
    request.path.to_s.start_with?("/t/")
  end

  def barbershop_from_path
    Barbershop.for_host(params[:slug].to_s)
  end

  # O tenant do desvio, levado de página em página pelo cookie.
  #
  # O slug é revalidado a cada requisição, e não confiado: uma barbearia
  # deletada entre uma página e outra não pode continuar aparecendo como se
  # existisse. O cookie é criptografado e `httponly`, então o cliente não escolhe
  # a barbearia — quem grava é a aplicação, a partir de um slug que existia.
  def barbershop_from_cookie
    return nil if Rails.env.production?

    slug = cookies.encrypted[TENANT_COOKIE]
    return nil if slug.blank?

    Barbershop.for_host(slug)
  end

  def resolve_barbershop
    SubdomainResolver.new(request.host_with_port).call
  end
end
