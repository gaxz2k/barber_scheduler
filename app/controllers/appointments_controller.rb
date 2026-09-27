class AppointmentsController < ApplicationController
  MAX_BOOKING_HORIZON = 1.year
  BOOKING_MIN_DAYS = 1

  before_action :set_booking_collections, only: [ :index, :new, :create, :availability ]
  before_action :set_booking_errors, only: [ :new, :create ]
  before_action :set_barbershop_unit, only: [ :index, :new, :create, :availability ]

  def index
    @booking_step = :service
    @barbershop_photos = BarbershopPhoto.published.limit(BarbershopPhoto::MAX_PUBLISHED_PHOTOS)
  end

  def new
    prepare_booking(
      service_id: params[:service],
      professional_id: params[:professional],
      date: params[:date]
    )
  end

  def create
    prepare_booking(
      service_id: booking_params[:service_id],
      professional_id: booking_params[:professional_id],
      date: booking_params[:date],
      date_default: false
    )

    if @selected_service.blank? || @selected_professional.blank? || @selected_date.blank?
      @booking_step = booking_step
      @appointment = Appointment.new
      @appointment.errors.add(:base, "Selecione serviço, profissional e data válidos.")
      @available_slots = []
      @booking_errors = [ "Selecione serviço, profissional e data válidos." ]
      render :new, status: :unprocessable_content
      return
    end

    if @barbershop_unit.blank?
      @booking_step = :schedule
      @appointment = Appointment.new
      @appointment.errors.add(:base, "Escolha a unidade.")
      @available_slots = []
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
      @booking_step = :schedule
      @appointment = result
      @appointment.service = @selected_service
      @appointment.professional = @selected_professional
      @appointment.start_at = booking_start_at
      @available_slots = available_slots
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
  helper_method :barbershop_unit

  private

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

  def set_booking_collections
    @services = Service.order(:name)
    @professionals = Professional.order(:name)
  end

  def set_booking_errors
    @booking_errors = []
  end

  def prepare_booking(service_id:, professional_id:, date:, date_default: true)
    @selected_service = find_service(service_id)
    @selected_professional = find_professional(professional_id) if @selected_service
    @selected_date = selected_date(date, default: date_default)
    @available_slots = available_slots
    @booking_step = booking_step
    @appointment = Appointment.new(
      service_id: @selected_service&.id,
      professional_id: @selected_professional&.id
    )
  end

  def booking_step
    return :service if @selected_service.blank?
    return :professional if @selected_professional.blank?

    :schedule
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

  def booking_start_at
    value = booking_params[:start_at]
    return if value.blank? || !value.is_a?(String)
    return unless strict_iso8601?(value)

    Time.zone.parse(value)
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
