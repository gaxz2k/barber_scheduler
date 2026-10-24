class Admin::BarbershopUnitsController < Admin::BaseController
  # Chave do `opening_hours` (0 = domingo) para o nome que o dono lê. Vive no
  # controller e não na view porque o formulário e a listagem precisam da mesma
  # ordem, e duas listas divergindo é como um dia aparece trocado.
  WEEK_DAYS = {
    "0" => "Domingo", "1" => "Segunda", "2" => "Terça", "3" => "Quarta",
    "4" => "Quinta", "5" => "Sexta", "6" => "Sábado"
  }.freeze

  before_action :set_barbershop_unit, only: [ :edit, :update ]

  def index
    @barbershop_units = Current.barbershop.unidades.order(:name)
  end

  def new
    @barbershop_unit = Current.barbershop.unidades.new
  end

  def edit
  end

  def create
    @barbershop_unit = Current.barbershop.unidades.new(unit_params)

    if @barbershop_unit.save
      redirect_to admin_barbershop_units_path, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @barbershop_unit.update(unit_params)
      redirect_to admin_barbershop_units_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  helper_method :formatar_minutos

  private

  # Minutos desde a meia-noite viram "08:00" para o dono ler.
  #
  # A conversão fica no controller, e não na view, porque o mesmo par é
  # gravado como string em `opening_hours` e lido como inteiro por
  # `BarbershopUnit#window_on?`; a view exibiria os minutos crus ("480") se
  # não houvesse um único lugar que sabe o formato.
  def formatar_minutos(minutos)
    format("%02d:%02d", minutos / 60, minutos % 60)
  end

  # A unidade vem do tenant em contexto pelo SLUG do path, nunca de um
  # `BarbershopUnit.find` global: `to_param` devolve o slug, e um slug de outra
  # barbearia não resolve aqui — o `default_scope` de tenant fecha a porta mesmo
  # se alguém tentar montar a consulta sem ele.
  def set_barbershop_unit
    @barbershop_unit = Current.barbershop.unidades.for_slug(params[:id])
    return if @barbershop_unit

    redirect_to admin_barbershop_units_path, alert: t(".not_found")
  end

  # `opening_hours` chega do formulário como `{ dia => { open, close } }`.
  #
  # O filtro é `[ :open, :close ]` — as duas chaves internas da janela, e não as
  # chaves de dia. A alternativa óbvia, um array com um hash por dia
  # (`{ "0" => [ :open, :close ] }`), foi testada no console e devolve
  # `{ "1" => {} }`: o `permit` de hash aninhado trata o valor do array como
  # filtro literal, e "08:00" não casa com a chave `open`. O filtro por chave
  # interna é o que preserva o que o navegador mandou, e ainda descarta as
  # chaves que não pertencem à janela.
  #
  # O dia não é filtrado porque o formulário sempre manda os sete, com string
  # vazia nos que o dono deixou fechado; o modelo trata dia vazio como dia
  # fechado. Filtrar por dia aqui faria a validação do modelo nunca ver o que
  # chegou do navegador.
  # `params.expect` foi tentado primeiro e não serve aqui: medido no console, ele
  # devolve `opening_hours => {}` com o hash aninhado, porque o `expect` trata o
  # valor da chave como filtro literal — o mesmo comportamento que o `permit`
  # documentado acima. O cop `Rails/StrongParametersExpect` sugere a forma
  # curta; ela perde o expediente, que é o único dado que esta tela grava.
  # rubocop:disable Rails/StrongParametersExpect
  def unit_params
    params.require(:barbershop_unit).permit(
      :name,
      :slug,
      opening_hours: [ :open, :close ]
    )
  end
  # rubocop:enable Rails/StrongParametersExpect
end
