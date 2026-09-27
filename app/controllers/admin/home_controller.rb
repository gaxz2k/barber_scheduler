class Admin::HomeController < Admin::BaseController
  # O que cada item da lista de pendências é: o nome que o dono lê e a tela que
  # resolve o item. Vive aqui, e não na view, porque a lista de caminhos é uma
  # decisão de navegação — a view não deve saber que "horarios" mora na tela de
  # unidades.
  #
  # O destino é o NOME do helper de rota, e não a string do caminho: passar o
  # símbolo direto para `link_to` faria o `url_for` tratar `:admin_services_path`
  # como rota e procurar `admin_services_path_path`.
  SETUP_LINKS = {
    unidades: [ "Unidades", :admin_barbershop_units_path ],
    servicos: [ "Serviços", :admin_services_path ],
    profissionais: [ "Profissionais", :admin_professionals_path ],
    horarios: [ "Horário de funcionamento", :admin_barbershop_units_path ]
  }.freeze

  # A prontidão vem do tenant em contexto, e não de uma busca por nome: a
  # home responde sobre a barbearia que o subdomínio resolveu, que é a única
  # que este painel administra.
  def index
    @missing_setup = Current.barbershop&.missing_setup || []
  end

  helper_method :setup_label, :setup_path

  private

  def setup_label(item)
    setup_link(item).first
  end

  # O Horário de funcionamento é o mesmo item que a unidade: a tela de unidades
  # é onde a janela de cada loja se cadastra. Um quarto caminho inventado seria
  # uma tela que não existe.
  #
  # Um item sem par cadastrado cai na própria home, em vez de estourar: a
  # lista vem do modelo, e um item novo lá sem linha aqui deve aparecer no
  # painel, não derrubar a página do administrador.
  def setup_path(item)
    public_send(setup_link(item).last)
  end

  def setup_link(item)
    SETUP_LINKS.fetch(item) { [ item.to_s.humanize, :admin_root_path ] }
  end
end
