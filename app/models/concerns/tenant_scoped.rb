# frozen_string_literal: true

# Escopo de tenant, aplicado por padrão.
#
# Um model que usa este concern nunca devolve linhas de outra barbearia por
# acidente: o filtro entra no default_scope, e não em cada consulta. A opção
# escolhida foi o default que bloqueia, porque a falha de uma query sem filtro
# é silenciosa — a tela de uma barbearia passa a listar os clientes de outra, e
# nenhum teste quebra se ninguém pensou nisso.
#
# Quem precisa de acesso global usa `without_tenant_scope` ou `across_tenants`,
# que são nomeados para aparecerem em revisão. `tenant_scoped = false` NÃO dá
# acesso global: ele só desliga as validações de escrita, e o `default_scope`
# continua filtrando a leitura. Os casos são raros e todos explícitos: a resolução
# do subdomínio e o backfill da migration.
#
# A escrita é protegida à parte, porque `default_scope` não impede
# `Model.create!(barbershop: outra_barbershop)`, nem impede
# `Model.create!(professional: profissional_de_outra)`: ele filtra leitura.
module TenantScoped
  extend ActiveSupport::Concern

  included do
    class_attribute :tenant_scoped, instance_writer: false, default: true

    belongs_to :barbershop, optional: true

    # Associações que apontam para outro model de tenant. Cada uma é conferida
    # em `barbershop_associations_match_current`, porque `belongs_to` guarda o
    # id que recebeu e não consulta o destino: sem isso, um registro da
    # barbearia A aceitaria apontar para linhas da B sem reclamar.
    class_attribute :tenant_associations, instance_writer: false, default: [].freeze

    # Não há callback preenchendo o barbershop_id: no Rails 8.1 o
    # `default_scope { where(...) }` é reescrito como `create_with` e já grava o
    # id no `.new`. Foi medido — um model só com `default_scope` nasce com o id
    # preenchido, e um model só com `belongs_to` nasce sem ele. Um callback aqui
    # seria uma segunda fonte de verdade para o mesmo campo.
    validate :barbershop_matches_current
    validate :tenant_associations_match_current
  end

  class_methods do
    # Declara quais associações `belongs_to` apontam para outro model de
    # tenant, para que a validação confira a que barbearia elas pertencem.
    # Chamar logo depois de `include TenantScoped`, no mesmo lugar de
    # `apply_tenant_scope`.
    def validates_tenant_associations(*names)
      self.tenant_associations = names.freeze
    end

    # Declara o filtro uma vez, como default_scope do model. É o que o model
    # chama logo depois de `include TenantScoped`.
    def apply_tenant_scope
      default_scope { where(barbershop_id: Current.barbershop_id) }
    end

    # Acesso global, ignorando Current.barbershop. Para uso excepcional e
    # consciente; o nome longo é de propósito, para aparecer em revisão.
    #
    # É `unscoped` sem reaplicar nada: quem chama está dizendo que quer ver
    # além da fronteira. Para contar o que existe de fato em todas as
    # barbearias, use `across_tenants`.
    def without_tenant_scope
      unscoped
    end

    # Busca dentro de um tenant específico, sem mexer em Current. Usado pela
    # resolução do subdomínio e pelos jobs que rodam sem requisição.
    def for_barbershop(barbershop)
      unscoped.where(barbershop_id: barbershop)
    end

    # Todos os tenants, para administration e migrações. Ainda mais explícito
    # que `without_tenant_scope`, que aqui seria enganoso: o nome diz que o
    # escopo é ignorado, não que a intenção é ver tudo.
    def across_tenants
      unscoped
    end
  end

  private

  # Cada `belongs_to` de tenant tem de pertencer à mesma barbearia do registro.
  #
  # A comparação é feita pelo id lido direto na coluna, e não pelo objeto
  # associado, porque o objeto passa pelo escopo padrão: se a linha fosse de
  # outra barbearia, `public_send(nome)` viraria nil e a comparação pareceria
  # "_está em branco_", que é um diagnóstico errado. O id cru é o que foi de
  # fato persistido.
  #
  # O model dono da associação vem da reflexão, e não de `self.class`: aqui o
  # self é o Appointment, e quem tem o `barbershop_id` é o Professional, o
  # Client ou o Service apontado. Ler em `self.class` buscaria a coluna
  # `barbershop_id` na tabela errada.
  def tenant_associations_match_current
    return unless tenant_scoped
    return if Current.barbershop_id.nil?

    tenant_associations.each do |name|
      foreign_id = self[name.to_s + "_id"]
      next if foreign_id.blank?

      owner_class = self.class.reflect_on_association(name)&.klass
      next if owner_class.nil? || !owner_class.respond_to?(:without_tenant_scope)

      owner_id = owner_class.without_tenant_scope.where(id: foreign_id).pick(:barbershop_id)
      next if owner_id.nil? # a linha não existe: deixa o belongs_to comum reclamar
      next if owner_id == barbershop_id

      errors.add(name, "não pode pertencer a outra barbearia")
    end
  end

  def barbershop_matches_current
    return unless tenant_scoped

    # Sem Current — um job sem requisição, um console — o escopo não tem contra
    # o que filtrar. Aceitar aqui deixaria passar qualquer barbershop_id, e o
    # registro nasceria sem vínculo nenhum. Melhor falhar alto.
    if Current.barbershop_id.nil?
      errors.add(:barbershop, "não pode ser criado fora de uma requisição")
      return
    end

    if barbershop_id.blank?
      errors.add(:barbershop, "não pode ficar em branco")
    elsif barbershop_id != Current.barbershop_id
      errors.add(:barbershop, "não pode pertencer a outra barbearia")
    end
  end
end
