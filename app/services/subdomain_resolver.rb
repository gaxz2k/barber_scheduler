# frozen_string_literal: true

# Resolve a barbearia da requisição a partir do subdomínio do host.
#
# Esta é a única peça que decide de quem é a requisição, e por isso concentra a
# regra. Devolve nil quando o host não corresponde a nenhuma barbearia, e quem
# chama decide o que fazer — a resposta é 404, para não revelar se existe uma
# plataforma com outras barbearias.
class SubdomainResolver
  # Em desenvolvimento o host base precisa ser um domínio que o browser
  # resolva para 127.0.0.1 sem configuração: `localhost` já faz isso, e
  # `senhor-r.localhost` também, que é o que permite abrir duas barbearias em
  # abas diferentes na mesma máquina.
  DEVELOPMENT_ROOT_HOST = "localhost"
  TEST_ROOT_HOST = "example.com"

  def initialize(host, root_host = nil)
    @host = host.to_s.downcase
    @root_host = (root_host || self.class.default_root_host).to_s.downcase
  end

  # O domínio base contra o qual o subdomínio é lido. É configuração, e não
  # constante, porque a URL pública muda entre ambientes e o acesso de quem
  # olha a demonstração de fora não vem de `localhost`.
  #
  # `BARBERSHOP_ROOT_HOST` é lido em qualquer ambiente, e não só em produção: a
  # vitrine precisa ser acessível por um nome que o navegador resolva, e
  # `slug.187.127.27.192` só funciona se a base for esse IP. Sem esta leitura,
  # abrir a demo pela internet daria 404 — o host não teria subdomínio para o
  # resolver ler — com um sintoma que parece ausência de barbearia e não
  # configuração.
  #
  # O valor padrão por ambiente continua valendo quando a variável não está
  # definida: `localhost` em desenvolvimento, `example.com` em teste e
  # `barbearia.app` em produção.
  def self.default_root_host
    return ENV["BARBERSHOP_ROOT_HOST"].to_s.strip if ENV["BARBERSHOP_ROOT_HOST"].to_s.strip.present?

    return TEST_ROOT_HOST if Rails.env.test?
    return DEVELOPMENT_ROOT_HOST unless Rails.env.production?

    "barbearia.app"
  end

  def call
    slug = subdomain
    return nil if slug.blank?

    Barbershop.for_host(slug)
  end

  # O subdomínio, já sem porta e sem o domínio base.
  #
  # `senior-r.barbearia.app:3000` com base `barbearia.app` devolve `senior-r`.
  # Um host que é a própria base não tem subdomínio e devolve nil — a raiz não
  # identifica ninguém.
  def subdomain
    host_without_port = utf8(@host).split(":").first.to_s
    return nil unless host_without_port.end_with?(".#{@root_host}")

    host_without_port.delete_suffix(".#{@root_host}")
  end

  private

  # `request.host_with_port` chega em ASCII-8BIT, e `parameterize` — tanto o do
  # resolver quanto o do `Barbershop.for_host` — levanta ArgumentError ao tentar
  # transliterar bytes em vez de convertê-los. Normalizar na entrada resolve
  # nos dois lugares, e é a fronteira certa: nenhum dos dois deve precisar
  # saber de onde veio a string.
  def utf8(value)
    value.to_s.encoding == Encoding::ASCII_8BIT ? value.to_s.force_encoding(Encoding::UTF_8) : value.to_s
  end

  attr_reader :host, :root_host
end
