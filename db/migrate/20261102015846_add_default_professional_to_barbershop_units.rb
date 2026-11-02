class AddDefaultProfessionalToBarbershopUnits < ActiveRecord::Migration[8.1]
  # O profissional padrão mora em `barbershop_units`, e não em `barbershops`
  # ou em `professionals`.
  #
  # Por que não em `barbershops`: agenda e profissionais já são organizados
  # por unidade neste projeto inteiro (`Professional#barbershop_unit`,
  # `Professional.for_unit`, o filtro de `AppointmentsController`) — um
  # padrão por barbearia obrigaria a Unidade Centro e a Unidade Jardim a
  # compartilhar o mesmo profissional pré-selecionado mesmo quando elas têm
  # equipes diferentes, o que é exatamente o problema que o filtro por
  # unidade já resolveu para a lista de profissionais.
  #
  # Por que não em `professionals` (um booleano `is_default`): um
  # profissional não é "o padrão" sozinho, ele é o padrão DE UMA UNIDADE — a
  # mesma Camila pode ser a padrão da Unidade Centro e não ser a padrão da
  # Unidade Jardim (onde ela também atende, por não ter unidade fixa). Um
  # booleano na tabela errada criaria um padrão global por acidente, sem
  # forma de expressar "padrão aqui, não ali".
  #
  # `null: true` (nulo permitido) porque a maioria das barbearias não vai
  # configurar isto: sem padrão definido, a tela de agendamento cai no
  # primeiro profissional da lista — o mesmo comportamento implícito que já
  # existia antes desta coluna existir. Exigir a coluna preenchida obrigaria
  # todo dono a escolher um profissional padrão antes de poder usar o
  # sistema, por uma conveniência que ele pode nem querer.
  #
  # `foreign_key: { to_table: :professionals }` porque o Rails infere o nome
  # da tabela a partir do nome da referência (`default_professional` →
  # `default_professionals`, que não existe) — sem o `to_table` explícito a
  # migration apontaria a FK para uma tabela inexistente e falharia ao
  # rodar.
  def change
    add_reference :barbershop_units, :default_professional,
                  null: true,
                  foreign_key: { to_table: :professionals },
                  index: true
  end
end
