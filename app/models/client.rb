class Client < ApplicationRecord
  include TenantScoped
  apply_tenant_scope

  validates :phone, :name, presence: true
  # E-mail é opcional (a referência SimplesAgenda nunca marca com asterisco),
  # mas quando preenchido precisa ter cara de e-mail — URI::MailTo::EMAIL_REGEXP
  # é a mesma regex que o Devise usa para o campo de e-mail do usuário.
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  # CPF é opcional por padrão (só aparece no formulário quando a barbearia
  # ativa `ShopSetting#collect_cpf?`), mas quando chega precisa ser um CPF
  # real — os 11 dígitos sozinhos não bastam, porque "11111111111" passa no
  # tamanho e falha nos dígitos verificadores.
  validate :cpf_must_be_valid, if: -> { cpf.present? }
  validates :cpf, uniqueness: { scope: :barbershop_id }, allow_blank: true
  has_many :appointments, dependent: :restrict_with_error

  # Telefone com os quatro últimos dígitos preservados: o bastante para o
  # cliente confirmar que é o próprio agendamento, sem expor o número inteiro
  # numa página acessível por link.
  def masked_phone
    digits = phone.to_s.gsub(/\D/, "")
    return phone if digits.length < 4

    "#{"*" * (digits.length - 4)}#{digits.last(4)}"
  end

  private

  # Algoritmo oficial do CPF: dois dígitos verificadores, cada um a soma
  # ponderada dos dígitos anteriores módulo 11. Sequências de um único
  # dígito repetido (ex. "11111111111") têm dígitos verificadores que batem
  # por coincidência aritmética e precisam de uma recusa explícita.
  def cpf_must_be_valid
    digits = cpf.to_s.gsub(/\D/, "")

    unless digits.length == 11 && digits.chars.uniq.size > 1 && valid_cpf_digits?(digits)
      errors.add(:cpf, "é inválido")
    end
  end

  def valid_cpf_digits?(digits)
    numbers = digits.chars.map(&:to_i)
    first_check = cpf_checksum_digit(numbers[0, 9])
    return false unless first_check == numbers[9]

    cpf_checksum_digit(numbers[0, 10]) == numbers[10]
  end

  def cpf_checksum_digit(base_digits)
    weight = base_digits.length + 1
    sum = base_digits.sum { |digit| digit * weight.tap { weight -= 1 } }
    remainder = (sum * 10) % 11
    remainder == 10 ? 0 : remainder
  end
end
