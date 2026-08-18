class AppointmentsController < ApplicationController
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
      redirect_to @appointment, notice: "Agendamento criado com sucesso."
    else
      render :new
    end
  end

  def update
    if @appointment.update(appointment_params)
      redirect_to @appointment, notice: "Agendamento atualizado com sucesso."
    else
      render :edit
    end
  end

  def destroy
    @appointment.destroy
    redirect_to appointments_url, notice: "Agendamento excluído com sucesso."
  end

  private

  def appointment_params
    params.expect(appointment: [ :client_id, :barber_id, :service_id, :start_at, :end_at ])
  end

  def set_appointment
    @appointment = Appointment.find(params[:id])
  end
end
