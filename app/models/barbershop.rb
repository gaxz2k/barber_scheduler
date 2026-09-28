class Barbershop < ApplicationRecord
  # O código do país usado para montar o link de WhatsApp. Fica como constante
  # e não dentro do método porque o método é chamado em view, e um literal
  # solto ali seria um número mágico sem explicação.
  CODIGO_DO_PAIS = "55"
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
  has_many :unidades, class_name: "BarbershopUnit", inverse_of: :barbershop, dependent: :destroy
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

  # O que ainda falta para a barbearia poder atender.
  #
  # Os quatro itens são o mínimo do caminho de reserva: sem serviço não há o
  # que agendar, sem profissional não há quem atenda, sem horário de
  # funcionamento a agenda fica vazia (a unidade já nasce com uma), e sem
  # nenhuma unidade não há onde o cliente escolha ir.
  #
  # Devolve símbolos, e não texto, para a interface poder linkar cada item na
  # tela certa sem adivinhar o que significa. Um texto aqui obrigaria a view a
  # fazer parse de string para descobrir o que falta.
  #
  # `:unidades` só aparece quando a lista está realmente vazia, o que só
  # acontece por remoção manual — a criação da unidade principal é
  # garantida pelo `after_create`.
  def missing_setup
    faltando = []
    faltando << :unidades if unidades.none?
    faltando << :servicos if services.none?
    faltando << :profissionais if professionals.none?
    # Uma unidade sem expediente NÃO impede a barbearia de estar pronta: o
    # cliente que escolher aquela loja vê agenda vazia, que é a resposta
    # correta para uma loja que não atende naquele dia. O que bloquearia o
    # cadastro inteiro seria nenhuma unidade ter horário — aí não existe lugar
    # nenhum onde agendar.
    #
    # O teste é "alguma unidade tem alguma janela de verdade", e não
    # `opening_hours.present?`: o formulário de unidades sempre submete os sete
    # dias, com string vazia nos que o dono deixou fechado, então o
    # `opening_hours` de uma unidade recém-criada é `{}` — mas um hash com
    # `{"1"=>{"open"=>"", "close"=>""}, ...}` também é `present?` e não define
    # expediente nenhum. Com o teste frouxo o painel declarava a barbearia
    # pronta logo depois de salvar a unidade vazia, que é exatamente o caso que
    # o aviso existe para pegar.
    faltando << :horarios if unidades.any? && unidades.none? { |unit| unit.serves_on_any_day? }
    faltando
  end

  def setup_complete?
    missing_setup.empty?
  end

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

  # O link de WhatsApp, já com o código do país.
  #
  # O `55` é o código do Brasil, e é o país do produto — a barbearia atendida
  # aqui está no Brasil, e um número cadastrado como "(11) 98888-1200" precisa
  # virar "55119888812000" para o link funcionar. O número gravado pode ou não
  # trazer o código: se trouxer, concatenar de novo produziria "5511988881200"
  # e o WhatsApp não abriria. Por isso a checagem, e não a concatenação cega.
  def whatsapp_link
    numero = whatsapp_number
    return nil if numero.blank?

    completo = numero.start_with?(CODIGO_DO_PAIS) ? numero : "#{CODIGO_DO_PAIS}#{numero}"
    "https://wa.me/#{completo}"
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
