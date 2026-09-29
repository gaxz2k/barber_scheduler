class AppointmentsController < ApplicationController
  MAX_BOOKING_HORIZON = 1.year
  BOOKING_MIN_DAYS = 1

  # Uma agenda: o profissional e os horários livres dele naquela data.
  #
  # É uma Struct, e não um Hash, porque a view acessa `agenda.professional` e
  # `agenda.slots` — e `agenda[:professional]` num template é um `agenda[:…]`
  # digitado certo só por acaso, sem o editor avisando quando o nome muda.
  #
  # Fica aqui, e não entre os métodos privados, porque uma constante escrita
  # depois de `private` continua pública mas parece privada — e o RuboCop
  # acusa esse acesso inútil, que aqui seria um sinal de onde o autor achava
  # que ela estava.
  Agenda = Data.define(:professional, :slots)

  before_action :set_booking_collections, only: [ :index, :new, :create, :availability ]
  before_action :set_booking_errors, only: [ :new, :create ]
  before_action :set_barbershop_unit, only: [ :index, :new, :create, :availability ]
  # A lista de unidades atende a home e a tela de agendamento, e precisa ficar
  # pronta nas duas. Ela morava no corpo de `index` e, quando `booking_step`
  # passou a ter a etapa `:unit` — para o caso de `unidade_slug` inválido, que
  # `set_barbershop_unit` devolve `nil` igual a "não escolhido" — a tela do `new`
  # passou a receber `@booking_units` nil e a quebrar com `any?` em nil.
  #
  # Só aparece quando a URL não traz unidade: com `unidade_slug` a escolha já
  # está feita, e repetir a lista seria pedir a mesma resposta duas vezes.
  before_action :set_booking_units, only: [ :index, :new, :create ]
  # A agenda é lida pela view em toda renderização de `new`, e nem todo caminho
  # passa por `prepare_booking` — um erro de validação monta `@appointment` à
  # mão. Sem este piso, a view receberia nil e quebraria ao chamar `each`, com
  # um NoMethodError no lugar do erro que o cliente deveria ler.
  before_action :set_agenda_padrao, only: [ :new, :create ]

  def index
    @booking_step = :service
    @barbershop_photos = BarbershopPhoto.published.limit(BarbershopPhoto::MAX_PUBLISHED_PHOTOS)
    @ultimo_agendamento = ultimo_agendamento
  end

  def new
    prepare_booking(
      service_id: params[:service],
      professional_id: params[:professional],
      date: params[:date]
    )
  end

  def create
    # O `start_at` chega como `profissional_id|horario` quando a escolha de
    # profissional e horário veio da tela fundida, e como o horário puro na
    # tela antiga. Os dois formatos são aceitos porque o link de uma etapa
    # antiga pode chegar por URL, e quem já estava na página não pode ver a
    # tela quebrar por um detalhe do formulário.
    escolha = slot_escolhido(booking_params[:start_at])
    # A tela a reenquadrar no erro é a fundida, e não a de horário: nesta o
    # profissional é escolhido junto com o horário, então `booking_step` já
    # diria "schedule" e o erro apareceria numa tela que não é a que o cliente
    # está vendo. O passo fica travado aqui e é recalculado só depois da
    # validação, quando a resposta é outra.
    @booking_step = :professional
    prepare_booking(
      service_id: booking_params[:service_id],
      professional_id: escolha[:professional_id] || booking_params[:professional_id],
      date: booking_params[:date],
      date_default: false
    )

    if @selected_service.blank? || @selected_professional.blank? || @selected_date.blank?
      # A etapa do erro é a do que falta, e não a fundida: sem serviço
      # escolhido a tela fundida mostraria o resumo "Serviço escolhido" com
      # um serviço que não existe. `booking_step` já devolve a etapa certa
      # — `:service` quando o serviço não veio, `:professional` quando veio
      # serviço mas não o dia.
      @booking_step = booking_step
      @appointment = Appointment.new
      @appointment.errors.add(:base, "Selecione serviço, profissional e data válidos.")
      @available_slots = []
      @agenda_por_profissional = agenda_por_profissional
      @booking_errors = [ "Selecione serviço, profissional e data válidos." ]
      render :new, status: :unprocessable_content
      return
    end

    if @barbershop_unit.blank?
      @booking_step = :professional
      @appointment = Appointment.new
      @appointment.errors.add(:base, "Escolha a unidade.")
      @available_slots = []
      @agenda_por_profissional = agenda_por_profissional
      @booking_errors = [ "Escolha a unidade." ]
      render :new, status: :unprocessable_content
      return
    end

    result = if public_slot_available?
               Appointments::PublicScheduler.call(
                 name: booking_params[:client_name],
                 phone: booking_params[:client_phone],
                 professional: @selected_professional,
                 service: @selected_service,
                 start_at: booking_start_at,
                 barbershop_unit: @barbershop_unit
               )
    else
               Appointment.new.tap { |appointment| appointment.errors.add(:base, "Escolha um horário disponível.") }
    end

    if result.persisted?
      redirect_to appointment_confirmation_path(token: result.confirmation_token),
                  notice: t(".success")
    else
      # O erro volta para a tela fundida, com a agenda de todo mundo de novo:
      # o cliente precisa reescolher o par (quem, quando), e mostrar só a agenda
      # do profissional que ele já tinha escolhido esconderia a alternativa.
      @booking_step = :professional
      @appointment = result
      @appointment.service = @selected_service
      @appointment.professional = @selected_professional
      @appointment.start_at = booking_start_at
      @available_slots = available_slots
      @agenda_por_profissional = agenda_por_profissional
      @booking_errors = result.errors.full_messages
      render :new, status: :unprocessable_content
    end
  end

  def availability
    @selected_service = find_service(params[:service_id])
    @selected_professional = find_professional(params[:professional_id])
    @selected_date = selected_date(params[:date])

    if @selected_service.blank? || @selected_professional.blank? || @selected_date.blank?
      render json: { error: "Selecione serviço, profissional e data futura." }, status: :unprocessable_content
    else
      render json: {
        date: @selected_date.iso8601,
        slots: available_slots.map { |slot| { value: slot.iso8601, label: slot.strftime("%H:%M") } }
      }
    end
  end

  # O link de confirmação chega por e-mail, e o subdomínio que o mailer escreveu
  # não é confiável — o cliente pode abrir pelo link de um celular com outro
  # navegador, ou o e-mail pode ser reencaminhado. Por isso a barbearia vem do
  # próprio token, e não do host.
  #
  # Cortar o escopo aqui é deliberado, e é o único ponto do código que faz isso.
  # A alternativa, exigir que o host bata com o token, transformaria um link de
  # e-mail em 404 sempre que o domínio mudasse. O risco é pequeno: o token tem
  # 32 caracteres de entropia, e a partir daqui Current passa a ser o da linha
  # encontrada, então o resto da requisição está no tenant certo.
  def confirmation
    @appointment = Appointment.without_tenant_scope.find_by(confirmation_token: params[:token])
    return redirect_to new_appointment_path, alert: t("appointments.create.invalid_confirmation") unless @appointment&.confirmation_accessible?

    Current.barbershop = @appointment.barbershop
    render :show
  end

  helper_method :confirmation_eyebrow, :confirmation_title, :confirmation_message
  # A unidade precisa ser legível pela view para o formulário mandar o `create`
  # para a URL certa. O método estava declarado como helper desde o commit que
  # introduziu a unidade na URL, mas nunca existiu: qualquer view que o
  # chamasse derrubaria a página com NoMethodError. `params[:unidade_slug]`
  # sozinho não serve, porque a view precisa da unidade resolvida, e não do
  # slug que o cliente pode ter digitado errado.
  helper_method :barbershop_unit, :booking_units, :unidade_path, :slot_preselecionado?

  private

  # A unidade resolvida para esta requisição, ou nil quando a URL não traz
  # slug — que é o mesmo estado de "não escolheu unidade", e o que a view
  # precisa para montar o link do formulário.
  def barbershop_unit
    @barbershop_unit
  end

  # O caminho da home com a unidade escolhida, para a lista de lojas da raiz.
  # Uma rota escrita à mão em vez do helper porque a raiz `/` não é o mesmo
  # endpoint que o escopo por unidade — são as duas entradas do mesmo fluxo.
  def unidade_path(unidade)
    "/barbearia/unidades/#{unidade.slug}"
  end

  # As unidades onde o cliente pode agendar agora, e só elas.
  #
  # Uma unidade sem nenhum dia de expediente aparece como agenda vazia para
  # quem a escolhe, e isso é a resposta certa — mas oferecer essa loja na lista
  # de escolha é levar o cliente a um beco sem saída, que não é a mesma coisa.
  # A lista é o caminho feliz; a loja fechada se descobre pelo link direto.
  def unidades_com_expediente
    BarbershopUnit.for_barbershop(Current.barbershop)
                  .select(&:serves_on_any_day?)
                  .sort_by(&:name)
  end

  # O último agendamento do cliente, para oferecer o atalho de refazer.
  #
  # Só `pending` e `confirmed`, e nunca `canceled` nem `completed`: um
  # agendamento cancelado é justamente o que o cliente não quer refazer, e
  # oferecer o atalho para um corte que já aconteceu seria sugerir que a
  # data passou. O limite de um é porque o botão é "refazer o último", e uma
  # lista de histórico é outra feature.
  def ultimo_agendamento
    Appointment.where(status: [ :pending, :confirmed ])
              .order(start_at: :desc)
              .first
  end

  # Reached only for pending and confirmed appointments: #confirmation
  # redirects away when confirmation_accessible? is false, which covers
  # canceled, completed and expired tokens. Keeping the canceled/completed
  # branches out of here is deliberate, so that relaxing the guard later
  # cannot silently start rendering customer data for a finished booking.
  def confirmation_eyebrow
    return "Tudo certo por aqui" if @appointment.confirmed?

    "Recebemos seu pedido"
  end

  def confirmation_title
    return "Agendamento confirmado" if @appointment.confirmed?

    "Agendamento solicitado"
  end

  def confirmation_message
    return "Seu horário está reservado. Guarde os detalhes abaixo para a sua chegada." if @appointment.confirmed?

    "Seu horário foi enviado para verificação pela equipe. O status aparece abaixo e pode ser atualizado pela barbearia."
  end

  # A unidade vem da URL e é sempre do tenant em `Current` — o slug é
  # procurado dentro da barbearia resolvida, nunca globalmente. Uma unidade de
  # outra barbearia com o mesmo slug devolve `nil` e a requisição recusa, que é
  # o mesmo comportamento de "não escolheu unidade".
  def set_barbershop_unit
    slug = params[:unidade_slug]
    return @barbershop_unit = nil if slug.blank?

    @barbershop_unit = BarbershopUnit.find_by(barbershop_id: Current.barbershop&.id, slug: slug)
  end

  # As unidades que podem receber o cliente agora: as que têm expediente em
  # algum dia. Uma loja sem horário não aparece nem para ser escolhida, porque
  # escolhê-la só adiaria a recusa do agendamento até o fim do caminho.
  def set_booking_units
    @booking_units = @barbershop_unit.blank? ? unidades_com_expediente : []
  end

  def set_booking_collections
    @services = Service.order(:name)
    @professionals = Professional.order(:name)
  end

  def set_booking_errors
    @booking_errors = []
  end

  def set_agenda_padrao
    @agenda_por_profissional ||= []
  end

  def prepare_booking(service_id:, professional_id:, date:, date_default: true)
    @selected_service = find_service(service_id)
    @selected_professional = find_professional(professional_id) if @selected_service
    @selected_date = selected_date(date, default: date_default)
    @available_slots = available_slots
    # A agenda vem depois de `@booking_step` porque dela depende: a grade de
    # todo mundo só é calculada enquanto a tela está pedindo quem faz o
    # serviço. Calcular antes testaria um `@booking_step` do request anterior.
    @booking_step = booking_step
    @agenda_por_profissional = agenda_por_profissional
    @appointment = Appointment.new(
      service_id: @selected_service&.id,
      professional_id: @selected_professional&.id
    )
  end

  # A agenda de cada profissional para a data escolhida, e só na etapa em que o
  # cliente ainda não escolheu quem.
  #
  # A data vem primeiro de propósito: ela é comum a todo mundo, e trocar o dia
  # recarrega a agenda inteira de uma vez. Recalcular por profissional só
  # depois é o que mantém a tela com um campo de data, e não um por agenda.
  #
  # Profissionais sem nenhum horário livre entram na lista com a agenda vazia,
  # e não são filtrados: "a Camila não tem vaga nesta data" é informação que o
  # cliente precisa antes de escolher outro dia, e um nome que sumiu da tela
  # parece um profissional que saiu da equipe.
  #
  # Quando o profissional veio da URL — o cliente escolheu "com Bruno" na lista
  # de serviços — a agenda é só dele. É o que a escolha significa: quem
  # escolheu o profissional quer a agenda dele, e mostrar as dos outros seria
  # desobedecer à escolha feita duas telas atrás. O nome continua visível, com
  # um link de volta para a comparação de todo mundo.
  def agenda_por_profissional
    return [] unless @selected_service && @selected_date && @booking_step == :professional

    lista = @selected_professional ? [ @selected_professional ] : @professionals
    lista.map do |professional|
      slots = AvailableSlots::Cache.fetch(
        professional: professional,
        date: @selected_date,
        service: @selected_service,
        barbershop_unit: @barbershop_unit
      )
      Agenda.new(professional: professional, slots: slots)
    end
  end

  # O par (profissional, horário) volta marcado quando o envio falhou.
  #
  # Comparar o `@appointment.start_at` com o slot já basta na tela antiga, onde
  # o profissional vinha de outro campo. Na fundida o mesmo horário aparece em
  # mais de uma agenda, e marcar todos marcaria vários radios de uma vez — o
  # que o navegador resolve por último, e o cliente não. Por isso o
  # profissional também é comparado.
  def slot_preselecionado?(professional, slot)
    return false if @appointment&.start_at.blank?

    @appointment.professional_id == professional.id && @appointment.start_at == slot
  end

  # A etapa que a tela mostra.
  #
  # Só existe uma etapa depois do serviço, e é a fundida: ela serve tanto para
  # "ainda não escolhi quem" quanto para "escolhi quem na lista de serviços".
  # O que muda entre os dois casos é a agenda — de todo mundo ou só do escolhido
  # — e não a tela. A etapa `:schedule`, que era a tela de horário separado, foi
  # removida de propósito: ela só existia depois que o profissional já estava
  # escolhido, e mostrava uma lista de horários sem foto e sem a comparação
  # que o cliente fez para chegar ali.
  def booking_step
    # A unidade vem primeiro, e é a única etapa que pode faltar mesmo com a
    # URL já escolhida: um `unidade_slug` inválido devolve `nil` de
    # `set_barbershop_unit`, e sem esta guarda a tela caía direto na lista de
    # serviços. O cliente veria serviços de uma unidade que ele não escolheu, e
    # o agendamento seria recusado só no fim do caminho — depois de preencher
    # nome e telefone.
    return :unit if @barbershop_unit.blank? && unidades_com_expediente.many?
    return :service if @selected_service.blank?

    :professional
  end

  def find_service(value)
    return unless value.is_a?(String) || value.is_a?(Integer)

    @services ||= Service.order(:name)
    @services.find_by(id: value)
  end

  def find_professional(value)
    return unless value.is_a?(String) || value.is_a?(Integer)

    @professionals ||= Professional.order(:name)
    @professionals.find_by(id: value)
  end

  def selected_date(value = params[:date], default: true)
    return if !default && (!value.is_a?(String) || value.blank?)

    date = value.present? ? Date.iso8601(value) : Date.current + 1
    minimum_date = Date.current + BOOKING_MIN_DAYS
    maximum_date = Date.current + MAX_BOOKING_HORIZON

    return if date < minimum_date || date > maximum_date

    date
  rescue Date::Error, TypeError
    nil
  end

  def available_slots
    return [] if @selected_service.blank? || @selected_professional.blank? || @selected_date.blank?

    AvailableSlots::Cache.fetch(
      professional: @selected_professional,
      date: @selected_date,
      service: @selected_service,
      barbershop_unit: @barbershop_unit
    )
  end

  def public_slot_available?
    start_at = booking_start_at
    return false if start_at.blank? || @selected_date.blank?
    return false unless start_at.to_date == @selected_date

    available_slots.any? { |slot| slot.to_i == start_at.to_i }
  end

  def booking_params
    appointment_params = params[:appointment]
    return ActionController::Parameters.new unless appointment_params.is_a?(ActionController::Parameters)

    appointment_params.permit(:service_id, :professional_id, :date, :start_at, :client_name, :client_phone)
  end

  # Separa o `profissional_id|horario` que a tela fundida monta.
  #
  # O profissional NÃO é confiado: ele é revalidado em `prepare_booking` contra
  # os profissionais do tenant, e o horário é revalidado contra a agenda real
  # daquele profissional em `public_slot_available?`. O par serve para dizer ao
  # servidor qual agenda conferir — não para dar como válido um par qualquer.
  #
  # Um valor sem o separador volta como `{}`, e o `create` cai no
  # `professional_id` do campo escondido, que é o caminho da tela antiga. Uma
  # requisição forjada não ganha nada com isto, e um formulário válido não é
  # recusado por causa de um caractere a mais.
  def slot_escolhido(valor)
    profissional, horario = valor.to_s.split("|", 2)
    return {} if horario.blank? || !horario.match?(/T\d{2}:\d{2}/)

    { professional_id: profissional, start_at: horario }
  end

  def booking_start_at
    # Na tela fundida o `start_at` é o par; o horário puro está depois do
    # separador. Preferir o horário isolado aqui mantém uma única leitura de
    # "que horas é" para as duas telas, em vez de cada uma cortar a string do
    # seu jeito.
    valor = slot_escolhido(booking_params[:start_at])[:start_at] || booking_params[:start_at]
    return if valor.blank? || !valor.is_a?(String)
    return unless strict_iso8601?(valor)

    Time.zone.parse(valor)
  rescue ArgumentError, TypeError => error
    Rails.logger.warn("Invalid public booking start_at: #{error.class}")
    nil
  end

  def strict_iso8601?(value)
    match = value.match(/\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z|[+-](\d{2}):(\d{2}))\z/)
    return false unless match && valid_iso8601_components?(match[1..6]) && valid_iso8601_offset?(match[9], match[10])

    Time.iso8601(value).present?
  rescue ArgumentError, TypeError
    false
  end

  def valid_iso8601_components?(components)
    year, month, day, hour, minute, second = components
    Date.iso8601("#{year}-#{month}-#{day}") &&
      hour.to_i.between?(0, 23) && minute.to_i.between?(0, 59) && second.to_i.between?(0, 59)
  rescue Date::Error
    false
  end

  def valid_iso8601_offset?(hours, minutes)
    return true if hours.nil? && minutes.nil?

    hour = hours.to_i
    minute = minutes.to_i

    hour.between?(0, 14) && minute.between?(0, 59) && (hour < 14 || minute.zero?)
  end
end
