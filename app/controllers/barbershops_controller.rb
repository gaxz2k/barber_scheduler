# frozen_string_literal: true

# A criação de uma barbearia.
#
# Este controller é o único lugar do sistema que roda FORA de um tenant, e por
# isso ele herda de `ActionController::Base` e não de `ApplicationController`:
# o `around_action :use_current_barbershop` do pai levanta `RecordNotFound`
# quando o tenant não resolve, e aqui a requisição chega sem host de barbearia e
# sem cookie — é ela que produz o primeiro tenant. Herdar do pai transformaria
# "criar sua barbearia" em um 404 silencioso.
#
# A consequência é recarregar à mão o que a classe base fazia e que ainda
# importa: proteção de CSRF e o layout. A lista é curta e fica declarada aqui de
# propósito — omitir uma delas seria um furo de segurança, e nada avisa.
#
# `allow_browser versions: :modern` fica de fora de propósito. Ele existe no
# pai para barrar navegadores que não suportam o que a vitrine usa, e um
# cadastro de barbearia não usa nada disso: é um formulário de seis campos. Quem
# cria a casa é o dono, e o dono não é o público do agendamento.
#
# `Rails/ApplicationController` exige herdar do pai, e aqui isso é justamente o
# defeito: o `around_action :use_current_barbershop` do pai é a fronteira de
# tenant, e esta requisição é a única que a atravessa porque produz o primeiro
# tenant. Herdar transforma o cadastro em 404. A regra está desligada só para
# esta linha, e o motivo está no topo do arquivo.
class BarbershopsController < ActionController::Base # rubocop:disable Rails/ApplicationController
  protect_from_forgery with: :exception
  layout "application"

  def new
    @barbershop = Barbershop.new
    @user = User.new
  end

  def create
    resultado = Barbershops::Create.new(
      attributes: barbershop_params,
      user_attributes: user_params
    ).call

    # O login é automático, e não um convite a logar em seguida: quem acabou de
    # criar a casa é o dono dela, e mandá-lo para a tela de login só para
    # digitar o que ele acabou de digitar é um passo inútil. A sessão é a do
    # dono porque o usuário que o service object criou é ele.
    sign_in(resultado.user)
    # O painel só abre num host de tenant. A requisição chegou em `localhost`
    # — o host do cadastro, que por definição não pertence a ninguém —, então
    # um `redirect_to admin_root_path` relativo cairia no painel do host vazio
    # e a tela seguinte levantaria `RecordNotFound`. É por isso que o caminho
    # absoluto é obrigatório aqui, e não um detalhe de URL.
    #
    # A raiz do host depende do ambiente: em desenvolvimento é `localhost`, em
    # produção é o domínio do `BARBERSHOP_ROOT_HOST`, e em teste é `example.com`.
    # Reutilizar a constante do resolver é o que impede a barra de divergir
    # entre o cadastro e a resolução de subdomínio.
    # `allow_other_host: true` é obrigatório e não é um atalho: o host da casa
    # recem-criada é, por definição, diferente do host da requisição, que é o
    # do cadastro. O Rails bloqueia redirect para outro host por padrão
    # (open redirect), e essa proteção existe porque normalmente é um ataque —
    # aqui é o único caminho possível, porque o painel da casa nova só existe
    # naquele host. A URL não vem do cliente: é montada do slug, que o service
    # object acabou de gravar, e da raiz do host, que vem do ambiente.
    redirect_to url_do_painel_da(resultado.barbershop),
                allow_other_host: true,
                notice: t(".criada")
  rescue Barbershops::Create::Invalid => e
    # O service object devolve códigos, não texto. A ordem em que ele valida é
    # a ordem em que a pessoa preenche o formulário, e a view mostra os erros
    # nessa ordem — traduzir no service misturaria regra de negócio com idioma.
    @barbershop = Barbershop.new(barbershop_params)
    @user = User.new(user_params)
    @erros = e.errors.map { |codigo| t("barbershops.errors.#{codigo}") }
    render :new, status: :unprocessable_content
  end

  private

  # O painel da casa recem-criada, no host dela.
  #
  # O caminho precisa ser absoluto porque o host da requisição é o host do
  # cadastro, que não pertence a ninguém. A raiz do host vem da mesma fonte que
  # o `SubdomainResolver` usa: se os dois divergirem, o dono cai num host que o
  # resolver não reconhece e volta para a vitrine.
  def url_do_painel_da(barbershop)
    "http://#{barbershop.slug}.#{raiz_do_host}:#{request.port}#{admin_root_path}"
  end

  def raiz_do_host
    if Rails.env.production?
      ENV.fetch("BARBERSHOP_ROOT_HOST", SubdomainResolver::DEVELOPMENT_ROOT_HOST)
    elsif Rails.env.test?
      SubdomainResolver::TEST_ROOT_HOST
    else
      SubdomainResolver::DEVELOPMENT_ROOT_HOST
    end
  end

  def barbershop_params
    params.expect(barbershop: [ :name, :slug, :timezone, :address, :phone, :whatsapp ])
  end

  def user_params
    params.expect(user: [ :email, :password, :password_confirmation ])
  end
end
