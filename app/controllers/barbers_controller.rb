class BarbersController < ApplicationController
  before_action :authenticate_user!, except: [ :index, :show ]
  before_action :require_admin!, only: [ :new, :create, :edit, :update, :destroy ]
  before_action :set_barber, only: [ :show, :edit, :update, :destroy ]

  def index
    @barbers = Barber.all
  end

  def show
  end
  def new
    @barber = Barber.new
  end
  def edit
  end

  def create
    @barber = Barber.new(barber_params)
    if @barber.save
      redirect_to @barber, notice: "Barbeiro criado com sucesso."
    else
      render :new
    end
  end
  def update
    if @barber.update(barber_params)
      redirect_to @barber, notice: "Barbeiro atualizado com sucesso."
    else
      render :edit
    end
  end

  def destroy
    @barber.destroy
    redirect_to barbers_url, notice: "Barbeiro excluído com sucesso."
  end

  private

  def barber_params
    params.expect(barber: [ :name ])
  end

  def set_barber
    @barber = Barber.find(params.expect(:id))
  end

  def require_admin!
    return if current_user.admin?

    redirect_to appointments_path, alert: "Acesso restrito a administradores."
  end
end
