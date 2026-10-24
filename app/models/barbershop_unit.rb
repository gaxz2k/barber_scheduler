# Uma unidade é um recorte dentro de uma barbearia, não um tenant novo.
#
# A fronteira de isolamento continua sendo `barbershops`. A unidade tem slug
# único POR BARBEARIA — duas barbearias podem ter ambas a unidade "centro", e
# isso é o que prova que a fronteira não se moveu para cá.
class BarbershopUnit < ApplicationRecord
  include TenantScoped
  apply_tenant_scope

  belongs_to :barbershop

  has_many :professionals, dependent: :nullify

  validates :name, presence: true
  # Unique no escopo da barbearia, e não `unique: true` global: duas
  # barbearias podem ter ambas a unidade "centro", e tornar o slug global
  # transferiria a fronteira de isolamento do tenant para o slug.
  validates :slug, presence: true, uniqueness: { scope: :barbershop_id }
  validates :slug, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }

  validate :opening_hours_are_well_formed

  before_validation :normalize_slug

  # O expediente é o que decide a agenda, então um horário mal formado é
  # recusado na gravação em vez de ser aceito e não servir para nada. A
  # validação é a mesma regra de `AvailableSlots::OpeningWindow`: "H:MM" com
  # H de 0 a 23, fechamento depois da abertura, e nada atravessando a
  # meia-noite. Divergir das duas deixaria cadastrar um horário que a agenda
  # ignora, e o dono acharia que configurou.
  HOUR_FORMAT = /\A([01]?\d|2[0-3]):([0-5]\d)\z/

  def opening_hours_are_well_formed
    return if opening_hours.blank?

    opening_hours.each do |dia, janela|
      unless dia.to_s.match?(/\A[0-6]\z/) && janela.is_a?(Hash)
        errors.add(:opening_hours, "tem um dia inválido: #{dia}")
        next
      end

      abertura = janela["open"].to_s.strip
      fechamento = janela["close"].to_s.strip

      # Dia sem horário é dia fechado, e é assim que o formulário sempre
      # manda: os sete dias chegam, com string vazia nos que o dono não
      # preencheu. Validar "" como formato inválido faria o cadastro inteiro
      # ser recusado, porque o formulário não tem como "não enviar" um dia.
      next if abertura.blank? && fechamento.blank?
      # Metade preenchida é erro de digitação, e silêncio seria pior: o dono
      # acharia que configurou um expediente que não existe.
      if abertura.blank? || fechamento.blank?
        errors.add(:opening_hours, "no dia #{dia} precisa ter abertura e fechamento, ou os dois vazios")
        next
      end

      minutos_abertura = parse_minutes(abertura)
      minutos_fechamento = parse_minutes(fechamento)

      if minutos_abertura.nil? || minutos_fechamento.nil?
        errors.add(:opening_hours, "no dia #{dia} precisa abrir e fechar no formato HH:MM")
      elsif minutos_fechamento <= minutos_abertura
        errors.add(:opening_hours, "no dia #{dia} fecha antes de abrir")
      end
    end
  end

  # A unidade atende em algum dia da semana?
  #
  # A pergunta é "existe alguma janela que a agenda consegue usar", e não
  # "o hash tem alguma chave": o formulário sempre submete os sete dias, com
  # string vazia nos fechados, e um hash desses não abre a agenda em dia
  # nenhum. `Barbershop#missing_setup` pergunta isto para saber se a barbearia
  # pode atender.
  def serves_on_any_day?
    return false unless opening_hours.is_a?(Hash)

    (0..6).any? { |dia| window_on?(dia) }
  end

  # A janela de um dia da semana, já convertida para minutos desde a
  # meia-noite, ou nil quando o dia não atende.
  #
  # Reusa as mesmas regras de `AvailableSlots::OpeningWindow`, porque a
  # resposta errada aqui é a pior possível: o painel diria que a barbearia
  # está pronta quando a agenda daquele dia está vazia.
  def window_on?(dia)
    janela = opening_hours.is_a?(Hash) ? opening_hours[dia.to_s] : nil
    return unless janela.is_a?(Hash)

    minutos_abertura = parse_minutes(janela["open"])
    minutos_fechamento = parse_minutes(janela["close"])
    return if minutos_abertura.nil? || minutos_fechamento.nil?
    return if minutos_fechamento <= minutos_abertura

    { open: minutos_abertura, close: minutos_fechamento }
  end

  def to_param
    slug
  end

  class << self
    # A unidade do slug dentro da barbearia do contexto. Devolve nil quando o
    # slug não existe ali — inclusive quando ele existe em outra barbearia, que
    # é o caso que impede a homônima de vazar.
    def for_slug(slug)
      return nil if slug.blank?

      where(slug: slug.to_s).first
    end
  end

  private

  def parse_minutes(value)
    return unless value.is_a?(String)

    match = value.strip.match(HOUR_FORMAT)
    return unless match

    (match[1].to_i * 60) + match[2].to_i
  end

  def normalize_slug
    self.slug = slug.to_s.parameterize.presence || name.to_s.parameterize
  end
end
