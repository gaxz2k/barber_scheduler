# frozen_string_literal: true

module Barbershops
  # Cria uma barbearia nova e o primeiro administrador dela, na mesma transação.
  #
  # Existe porque "criar uma barbearia" não é um `Barbershop.create!`: a conta
  # que administra precisa nascer junto, e sem a conta a casa fica órfã — o
  # painel exige `admin` **e** `barbershop_id` (ver
  # `User#atende_esta_barbershop?`), então uma barbearia sem dono não tem
  # ninguém que a administre. Criar as duas coisas em pontos diferentes abriria
  # a janela entre "barbearia criada" e "dono criado", e é nessa janela que
  # alguém criaria a mesma casa duas vezes.
  #
  # A transactagem é o que fecha essa janela: ou as duas coisas existem, ou
  # nenhuma. Sem ela, uma falha ao criar o usuário (e-mail repetido é o caso
  # comum, porque o e-mail tem unicidade global no Devise) deixaria uma
  # barbearia criada e sem dono, e o retry do usuário esbarraria no slug já
  # tomado.
  #
  # O e-mail do dono é global e único, então a checagem de duplicidade é
  # explícita e a mensagem é sobre o e-mail, não sobre o slug. Um signup que
  # dissesse "esse endereço já está em uso" quando o problema era o slug
  # mandaria o usuário corrigir a coisa errada.
  class Create
    # O fuso padrão de uma barbearia brasileira. Pedir o fuso no formulário é
    # um campo a mais para quase todo mundo errar; a agenda usa a data do
    # cliente, não a hora do servidor, então `America/Sao_Paulo` serve para a
    # esmagadora maioria e o campo fica disponível para quem precisa.
    FUSO_PADRAO = "America/Sao_Paulo"

    Result = Data.define(:barbershop, :user)

    # Erros de validação como códigos, não como texto. O service valida regra
    # de negócio e não sabe o idioma de quem vai ler: devolver "Esse endereço
    # público já está em uso" daqui amarra a regra à tela em português, e a
    # próxima vez que alguém pedir outra língua o service precisa ser reescrito.
    # O controller traduz por `barbershops.errors.<codigo>`.
    class Invalid < StandardError
      attr_reader :errors

      def initialize(codigos)
        @errors = codigos
        super(codigos.join(", "))
      end
    end

    def initialize(attributes:, user_attributes:)
      @attributes = attributes.to_h.symbolize_keys
      @user_attributes = user_attributes.to_h.symbolize_keys
    end

    def call
      validar!

      Barbershop.transaction do
        barbershop = Barbershop.create!(
          name: nome,
          slug: slug,
          timezone: fuso,
          address: @attributes[:address],
          phone: @attributes[:phone],
          whatsapp: @attributes[:whatsapp]
        )

        Current.barbershop = barbershop
        user = User.create!(
          email: @user_attributes[:email],
          password: @user_attributes[:password],
          password_confirmation: @user_attributes[:password_confirmation],
          admin: true,
          barbershop_id: barbershop.id
        )

        Result.new(barbershop: barbershop, user: user)
      end
    end

    private

    attr_reader :attributes, :user_attributes

    def nome
      attributes[:name].to_s.strip
    end

    # O slug vem do que o usuário digitou, e não de `parameterize` do nome: o
    # nome pode ser "Barbearia do Zé" e o endereço público `barbearia-do-ze`,
    # que é o que ele vai ditar para os clientes. Deixar os dois em campos
    # separados é o que permite a URL ser curta e o nome ter acento.
    def slug
      digitado = attributes[:slug].presence || nome
      digitado.to_s.parameterize
    end

    def fuso
      attributes[:timezone].presence || FUSO_PADRAO
    end

    def validar!
      erros = []

      erros << :nome_obrigatorio if nome.blank?
      erros << :slug_curto if slug.blank? || slug.length < 3
      erros << :slug_em_uso if slug.present? && Barbershop.unscoped.exists?(slug: slug)

      email = user_attributes[:email].to_s.strip.downcase
      erros << :email_obrigatorio if email.blank?
      erros << :email_em_uso if email.present? && User.unscoped.exists?(email: email)

      senha = user_attributes[:password].to_s
      erros << :senha_curta if senha.length < 8
      erros << :senha_nao_bate if senha.present? && senha != user_attributes[:password_confirmation].to_s

      raise Invalid, erros if erros.any?
    end
  end
end
