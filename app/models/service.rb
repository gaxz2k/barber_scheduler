class Service < ApplicationRecord
  include TenantScoped
  apply_tenant_scope

  validates :name, :duration_minutes, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  validate :duration_cannot_change_with_appointments
  has_many :appointments, dependent: :restrict_with_error

  # O preço como o cliente vê, ou nil quando não há preço.
  #
  # Nil, e não string vazia, porque a view decide se reserva o espaço: "R$ "
  # sozinho ocupa a linha e não diz nada.
  #
  # A formatação é do ActionView (`number_to_currency`) e não `to_fs` do
  # ActiveSupport: `to_fs` em um Integer devolve o número cru, sem separador nem
  # símbolo. Passar a formatação para o model é discutível, mas o preço é
  # domínio — é a regra de pagamento que decide o valor — e a view não deve
  # inventar a regra.
  def price_label
    return nil if price_cents.blank? || price_cents <= 0

    ActionController::Base.helpers.number_to_currency(price_cents / 100.0)
  end

  private

  def duration_cannot_change_with_appointments
    return unless persisted? && will_save_change_to_duration_minutes? && appointments.exists?

    errors.add(:duration_minutes, "não pode ser alterado quando existem agendamentos")
  end
end
