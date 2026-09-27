class Barbershop < ApplicationRecord
  # Uma barbearia é a fronteira de isolamento: todo dado de operação pertence a
  # uma, e nenhuma query sem escopo atravessa essa fronteira (ver TenantScoped).
  #
  # Este model não usa TenantScoped de propósito: ele é a coisa que o escopo
  # filtra, e filtrar a tabela de tenants por um tenant seria circular. É o
  # único model acessível sem contexto, e por isso `pluck(:slug)` na resolução
  # de subdomínio é seguro.

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

  def to_param
    slug
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

  def normalize_slug
    self.slug = slug.to_s.parameterize.presence || name.to_s.parameterize
  end
end
