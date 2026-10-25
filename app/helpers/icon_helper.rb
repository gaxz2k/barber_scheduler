# frozen_string_literal: true

# Ícones SVG inline para as ações mais comuns do produto.
#
# A escolha é um helper Ruby, e não dez partials em `app/views/shared/icons/`,
# por um motivo concreto: um ícone é markup estático de uma linha de dado (o
# `path`), sem lógica condicional nem necessidade de `render partial:` —
# dez arquivos de uma linha cada é dez `stat()` de disco a mais por página sem
# ganhar nada em troca. Um helper com um `case` devolve a mesma string e cabe
# inteiro numa tela, o que facilita comparar os `viewBox` e manter o traço
# (`stroke-width`) consistente entre todos.
#
# Caso um ícone cresça — precisar de estado (ativo/inativo) ou composição com
# outro elemento — ele migra para partial então, e não antes: a complexidade
# é o que justifica o arquivo próprio, não o número de ícones.
#
# Todos seguem o mesmo desenho: traço (`stroke`), sem preenchimento, 24x24,
# para herdar `color` do CSS e não precisar de uma cor própria por ícone —
# é o que deixa o ícone vermelho dentro de um `.alert--danger` sem nenhum
# código extra.
module IconHelper
  ICONS = {
    # Agenda do dia.
    calendar: '<path d="M8 2v4M16 2v4M3.5 9h17M4 5h16a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1Z"/>',
    # Horário de um agendamento.
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/>',
    # Cliente / profissional.
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7"/>',
    phone: '<path d="M6.5 3h3l1.5 4-2 1.5a12 12 0 0 0 6.5 6.5l1.5-2 4 1.5v3a1.5 1.5 0 0 1-1.6 1.5A17 17 0 0 1 5 7.6 1.5 1.5 0 0 1 6.5 3Z"/>',
    # Confirmar / sucesso.
    check: '<path d="M4 12.5 9 17 20 6.5"/>',
    # Cancelar / fechar.
    x: '<path d="M5 5l14 14M19 5 5 19"/>',
    # Contato por WhatsApp.
    whatsapp: '<path d="M12 3a9 9 0 0 0-7.8 13.5L3 21l4.7-1.2A9 9 0 1 0 12 3Z"/>' \
      '<path d="M8.5 9.3c.2-.6.7-.6 1.1-.5.3 0 .6.5 1 1.1.3.5.6 1 .3 1.4-.3.5-.8.6-.6 1.1.3.8 1.6 2 2.4 2.3.5.2.6-.3 1.1-.6.4-.3.9 0 1.4.3.5.4 1 .7 1 1-.1.8-1.3 1.3-2 1.3-1.6 0-4.2-1.4-5.4-3.4-.6-1-.8-1.8-.3-2.5-.1.1 0-.1 0 0Z"/>',
    # Agendamento online pausado.
    lock: '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    edit: '<path d="M4 20h4L19 9l-4-4L4 16v4Z"/><path d="M13 7l4 4"/>',
    trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
    # Menu (hambúrguer) do painel administrativo em tela estreita — ver
    # `.nav__toggle` em design_components.css.
    menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
    # Local/endereço — usado no marcador do cartão de unidade (escolha de
    # onde ser atendido), no lugar do número de sequência "01/02/03" que
    # sugeria uma ordem que a lista de unidades não tem.
    pin: '<path d="M12 21s7-6.2 7-11.5A7 7 0 0 0 5 9.5C5 14.8 12 21 12 21Z"/><circle cx="12" cy="9.5" r="2.5"/>',
    # Seta do seletor "com quem" (serviço → profissional) e do botão de
    # consulta estática — reaberto pelo redesenho mobile do agendamento
    # público (ver booking_wizard.css / #58-#60 e esta tarefa).
    "chevron-down": '<path d="M5 8.5 12 15.5 19 8.5"/>',
    # Botão flutuante "voltar ao topo" do fluxo público.
    "arrow-up": '<path d="M12 19V5M5.5 11.5 12 5l6.5 6.5"/>'
  }.freeze

  # Devolve o `<svg>` inline do ícone `name`. `size` é o lado em pixels (o
  # ícone é sempre quadrado) e `css_class` entra em `class=""` para quem
  # precisar de cor ou margem específica via CSS.
  def icon_tag(name, size: 20, css_class: nil, title: nil)
    body = ICONS.fetch(name) { raise ArgumentError, "ícone desconhecido: #{name.inspect}" }

    title_markup = title.present? ? content_tag(:title, title) : "".html_safe

    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="#{size}" height="#{size}"
           fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"
           stroke-linejoin="round" class="#{css_class}" aria-hidden="#{title.blank?}" role="img">
        #{title_markup}#{body}
      </svg>
    SVG

    svg.html_safe # rubocop:disable Rails/OutputSafety -- markup é fixo, vem só de ICONS, nunca de entrada do usuário.
  end
end
