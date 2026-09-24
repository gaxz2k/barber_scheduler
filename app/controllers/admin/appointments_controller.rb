class Admin::AppointmentsController < Admin::BaseController
  before_action :set_appointment, only: [ :show, :edit, :update, :destroy ]

  def index
    @appointments = Appointment.order(start_at: :asc)
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
