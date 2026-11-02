class Admin::ProfessionalsController < Admin::BaseController
  before_action :set_professional, only: [ :show, :edit, :update, :destroy, :set_default ]

  def index
    @professionals = Professional.order(:name)
  end

  def show
  end

  def new
    @professional = Professional.new
  end

  def edit
  end

  def create
    @professional = Professional.new(professional_params)
    if @professional.save
      redirect_to admin_professionals_path, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @professional.update(professional_params)
      redirect_to admin_professionals_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @professional.destroy
      redirect_to admin_professionals_path, notice: t(".success")
    else
      redirect_to admin_professionals_path, alert: t(".failure")
    end
  end

  # Marca este profissional como o padrão pré-selecionado no seletor "com
  # quem" da etapa de serviço, para a UNIDADE dele (ver o comentário de
  # `BarbershopUnit#default_professional` sobre por que o padrão é por
  # unidade, e não por profissional ou por barbearia).
  #
  # Um profissional sem `barbershop_unit` atende em QUALQUER unidade (ver
  # `Professional#for_unit`) — não faz sentido escolhê-lo como "o padrão da
  # unidade dele", porque ele não tem uma unidade só seria. Recusar aqui, e
  # não silenciosamente, porque marcar o campo errado (ou nenhum) deixaria o
  # dono achando que configurou algo que não teve efeito nenhum.
  def set_default
    if @professional.barbershop_unit.blank?
      redirect_to admin_professionals_path, alert: t(".no_unit")
      return
    end

    if @professional.barbershop_unit.update(default_professional: @professional)
      redirect_to admin_professionals_path, notice: t(".success")
    else
      redirect_to admin_professionals_path, alert: t(".failure")
    end
  end

  private

  def professional_params
    params.expect(professional: [ :name, :photo_upload, :remove_photo ])
  end

  def set_professional
    @professional = Professional.find(params.expect(:id))
  end
end
