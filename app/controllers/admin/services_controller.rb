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
      redirect_to admin_services_path, notice: t(".success")
    else
      render :new
    end
  end

  def update
    # with_lock reloads the row and holds SELECT ... FOR UPDATE until the update commits, so
    # a concurrent Appointments::Scheduler either reads the new duration or keeps the old one
    # under the same lock. Combined with the Service immutability validation, a duration change
    # is rejected as soon as any appointment exists.
    updated = @service.with_lock { @service.update(service_params) }

    if updated
      redirect_to admin_services_path, notice: t(".success")
    else
      render :edit
    end
  end

  def destroy
    @service.destroy
    redirect_to admin_services_path, notice: t(".success")
  end

  private

  def service_params
    params.expect(service: [ :name, :duration_minutes ])
  end

  def set_service
    @service = Service.find(params.expect(:id))
  end
end
