class Client < ApplicationRecord
  include TenantScoped
  apply_tenant_scope

  validates :phone, :name, presence: true
  has_many :appointments, dependent: :restrict_with_error

  # Telefone com os quatro últimos dígitos preservados: o bastante para o
  # cliente confirmar que é o próprio agendamento, sem expor o número inteiro
  # numa página acessível por link.
  def masked_phone
    digits = phone.to_s.gsub(/\D/, "")
    return phone if digits.length < 4

    "#{"*" * (digits.length - 4)}#{digits.last(4)}"
  end
end
