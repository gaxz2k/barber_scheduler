class Admin::ServicesController < Admin::BaseController
  before_action :set_service, only: [ :edit, :update, :destroy ]

  def index
    @services = Service.all
  end

  def new
    @service = Service.new
  end

  def edit
  end

  def create
    @service = Service.new(service_params)
    if @service.save
      redirect_to admin_services_path, notice: "Serviço criado com sucesso."
    else
      render :new
    end
  end

  def update
    if @service.update(service_params)
      redirect_to admin_services_path, notice: "Serviço atualizado com sucesso."
    else
      render :edit
    end
  end

  def destroy
    @service.destroy
    redirect_to admin_services_path, notice: "Serviço excluído com sucesso."
  end

  private

  def service_params
    params.expect(service: [ :name, :duration_minutes ])
  end

  def set_service
    @service = Service.find(params.expect(:id))
  end
end
