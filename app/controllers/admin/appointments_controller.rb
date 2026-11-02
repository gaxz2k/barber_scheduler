class Admin::AppointmentsController < Admin::BaseController
  before_action :set_appointment, only: [ :show, :edit, :update, :destroy ]

  # Os únicos filtros desta tela: status (os quatro valores reais do enum
  # `Appointment#status`, nenhum rótulo inventado) e busca por nome do
  # cliente. Vive como constante, e não espalhado no método, porque a view
  # dos chips precisa da MESMA lista — um chip para um status que o
  # controller não aceita seria um link morto.
  STATUS_FILTERS = Appointment.statuses.keys.freeze

  def index
    # `status` é um filtro OPCIONAL, não um parâmetro obrigatório: a tela sem
    # nenhum status escolhido (o caso mais comum, "ver tudo") não tem como
    # satisfazer `params.expect(:status)`, que levanta `ParameterMissing`
    # quando a chave não vem na querystring. `.expect` é para o parâmetro que
    # TEM que existir (como `:id` em `set_appointment`); aqui o valor ausente
    # é um estado válido da tela, não um erro de requisição — mesmo caso já
    # documentado em `Admin::BarbershopUnitsController#unit_params`.
    # rubocop:disable Rails/StrongParametersExpect
    @status_filter = params[:status].presence_in(STATUS_FILTERS)
    # rubocop:enable Rails/StrongParametersExpect
    @search = params[:q].to_s.strip

    @appointments = Appointment.order(start_at: :asc)
    @appointments = @appointments.where(status: @status_filter) if @status_filter
    @appointments = @appointments.joins(:client).where("clients.name ILIKE ?", "%#{@search}%") if @search.present?

    # As contagens do rodapé/chips usam a MESMA busca da lista principal, mas
    # NÃO o filtro de status — cada chip mostra quanto teria naquele status
    # dentro da busca atual, não quanto a tela está mostrando agora.
    @status_counts = Appointment.joins(:client)
                                 .then { |scope| @search.present? ? scope.where("clients.name ILIKE ?", "%#{@search}%") : scope }
                                 .group(:status).count
  end

  def show
  end

  def new
    @appointment = Appointment.new
  end

  def edit
  end

  def create
    @appointment = Appointment.new(appointment_params)
    if @appointment.save
      redirect_to admin_appointment_path(@appointment), notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @appointment.update(appointment_params)
      redirect_to admin_appointment_path(@appointment), notice: t(".success")
    else
      flash.now[:failure] = t(".failure")
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @appointment.destroy
      redirect_to admin_appointments_path, notice: t(".success")
    else
      redirect_to admin_appointments_path, alert: t(".failure")
    end
  end

  private

  def appointment_params
    params.expect(appointment: [ :client_id, :professional_id, :service_id, :start_at, :end_at ])
  end

  def set_appointment
    @appointment = Appointment.find(params.expect(:id))
  end
end
