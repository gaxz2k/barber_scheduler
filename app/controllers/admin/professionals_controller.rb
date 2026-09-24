class Admin::ProfessionalsController < Admin::BaseController
  before_action :set_professional, only: [ :show, :edit, :update, :destroy ]

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
      render :new
    end
  end

  def update
    if @professional.update(professional_params)
      redirect_to admin_professionals_path, notice: t(".success")
    else
      render :edit
    end
  end

  def destroy
    if @professional.destroy
      redirect_to admin_professionals_path, notice: t(".success")
    else
      redirect_to admin_professionals_path, alert: t(".failure")
    end
  end

  private

  def professional_params
    params.expect(professional: [ :name ])
  end

  def set_professional
    @professional = Professional.find(params.expect(:id))
  end
end
