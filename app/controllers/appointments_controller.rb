class AppointmentsController < ApplicationController
  before_action :set_appointment, only: [ :show ]

  def index
    @appointments = Appointment.order(start_at: :asc)
  end

  def show
  end

  def new
    @appointment = Appointment.new
  end

  def create
    @appointment = Appointment.new(appointment_params)
    if @appointment.save
      redirect_to @appointment, notice: t(".success")
    else
      render :new, status: :unprocessable_content
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
