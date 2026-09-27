class Barbershop < ApplicationRecord
  # Uma barbearia é a fronteira de isolamento: todo dado de operação pertence a
  # uma, e nenhuma query sem escopo atravessa essa fronteira (ver TenantScoped).
  #
  # Este model não usa TenantScoped de propósito: ele é a coisa que o escopo
  # filtra, e filtrar a tabela de tenants por um tenant seria circular. É o
  # único model acessível sem contexto, e por isso `pluck(:slug)` na resolução
  # de subdomínio é seguro.

  # `:class_name` explícito porque o Rails derivaria "Unidade" de "unidades" — o
  # nome singular da associação, que não existe. A associação chama unidades
  # porque é o termo do domínio; a classe chama BarbershopUnit porque é o termo
  # do código, e uma segunda tabela chamada "unidades" sem o prefixo seria
  # ambígua com a unidade de medida.
  has_many :unidades, class_name: "BarbershopUnit", dependent: :destroy
  has_many :clients, dependent: :restrict_with_error
  has_many :professionals, dependent: :restrict_with_error
  has_many :services, dependent: :restrict_with_error
  has_many :appointments, dependent: :restrict_with_error
  has_many :barbershop_photos, dependent: :restrict_with_error
  has_many :users, dependent: :nullify

  has_one_attached :logo

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :timezone, presence: true

  before_validation :normalize_slug
  # Uma barbearia nova precisa de uma unidade: `Appointment` exige uma, e uma
  # barbearia recém-criada sem unidade aceita cadastrar catálogo e recusa todo
  # agendamento. A migration faz o mesmo para as barbearias que já existiam;
  # aqui é para as que nascem depois.
  #
  # `Current` é ligado durante a criação porque a validação de TenantScoped
  # recusa gravar sem contexto, e a barbearia acabou de nascer — quem a cria
  # ainda não tem o tenant em `Current`. Só o próprio `barbershop_id` é
  # aceito, e é o caso certo: a unidade pertence à barbearia que está nascendo.
  after_create :create_primary_unit

  def to_param
    slug
  end

  # Busca pelo slug exato. É o que a resolução de subdomínio usa, e por isso
  # não aceita o slug parcial: "senior-r" não pode devolver a "senhor-r-filial".
  class << self
    def for_host(slug)
      return nil if slug.blank?

      where(slug: slug.to_s.parameterize).first
    end
  end

  def opening_hours_for(day)
    Array(opening_hours[day.to_s])
  end

  def open_on?(day)
    hours = opening_hours_for(day)
    hours.any? && hours.first.to_s < hours.last.to_s
  end

  def whatsapp_number
    whatsapp.to_s.gsub(/\D/, "")
  end

  private

  def create_primary_unit
    # `Current` entra só para a criação da unidade e sai logo depois: um job ou
    # um console que cria uma barbearia não deve ficar com o tenant grudado
    # depois disso, senão as consultas seguintes herdam a barbearia
    # recém-criada sem ninguém pedir.
    anterior = Current.barbershop
    Current.barbershop = self
    unidades.create!(name: name, slug: "principal", address: address, phone: phone, whatsapp: whatsapp)
  ensure
    Current.barbershop = anterior
  end

  def normalize_slug
    self.slug = slug.to_s.parameterize.presence || name.to_s.parameterize
  end
end
