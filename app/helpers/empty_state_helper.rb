# frozen_string_literal: true

# Ilustrações SVG para telas sem conteúdo ainda — "nenhum agendamento hoje",
# "nenhum profissional cadastrado", "nenhuma foto na galeria".
#
# Mesma decisão do `IconHelper` e pelo mesmo motivo: é markup estático sem
# lógica, então um helper Ruby concentra as três em um lugar só em vez de
# três arquivos de partial. A diferença para os ícones é de escala, não de
# natureza — por isso usam `viewBox` maior (96×96) e compõem mais de uma
# forma geométrica (círculo de fundo + traço simples), mas seguem a mesma
# regra de desenho: geométrico, flat, sem gradiente, só os tons da paleta
# nova (petróleo e coral) para não introduzir uma terceira paleta "só para
# ilustração".
module EmptyStateHelper
  ILLUSTRATIONS = {
    # "Nenhum agendamento hoje": uma página de agenda com uma linha tracejada
    # no lugar do horário que não existe ainda.
    no_appointments: <<~SVG,
      <circle cx="48" cy="48" r="46" fill="var(--dt-petrol-100)"/>
      <rect x="26" y="28" width="44" height="40" rx="6" fill="var(--dt-ice-0)" stroke="var(--dt-petrol-500)" stroke-width="2"/>
      <path d="M34 24v8M62 24v8" stroke="var(--dt-petrol-500)" stroke-width="2" stroke-linecap="round"/>
      <line x1="26" y1="40" x2="70" y2="40" stroke="var(--dt-petrol-500)" stroke-width="2"/>
      <line x1="34" y1="50" x2="54" y2="50" stroke="var(--dt-petrol-300)" stroke-width="2" stroke-dasharray="3 4" stroke-linecap="round"/>
      <line x1="34" y1="58" x2="46" y2="58" stroke="var(--dt-petrol-300)" stroke-width="2" stroke-dasharray="3 4" stroke-linecap="round"/>
    SVG

    # "Nenhum profissional cadastrado": uma silhueta sozinha com um "+" ao
    # lado, convidando a cadastrar a primeira.
    no_professionals: <<~SVG,
      <circle cx="48" cy="48" r="46" fill="var(--dt-petrol-100)"/>
      <circle cx="42" cy="38" r="10" fill="var(--dt-ice-0)" stroke="var(--dt-petrol-500)" stroke-width="2"/>
      <path d="M24 70c0-10 8-16 18-16s18 6 18 16" fill="var(--dt-ice-0)" stroke="var(--dt-petrol-500)" stroke-width="2"/>
      <circle cx="68" cy="30" r="9" fill="var(--dt-coral-500)"/>
      <path d="M68 26v8M64 30h8" stroke="var(--dt-ice-0)" stroke-width="2" stroke-linecap="round"/>
    SVG

    # "Nenhuma foto na galeria": uma moldura de foto com um sol e uma
    # montanha simplificados, no estilo de placeholder genérico de imagem.
    no_gallery_photos: <<~SVG,
      <circle cx="48" cy="48" r="46" fill="var(--dt-petrol-100)"/>
      <rect x="22" y="30" width="52" height="38" rx="6" fill="var(--dt-ice-0)" stroke="var(--dt-petrol-500)" stroke-width="2"/>
      <circle cx="34" cy="42" r="5" fill="var(--dt-coral-400)"/>
      <path d="M22 62l14-12 10 8 8-10 20 16" fill="none" stroke="var(--dt-petrol-500)" stroke-width="2" stroke-linejoin="round"/>
    SVG

    # Genérico reutilizável, para qualquer lista vazia que não tenha uma
    # ilustração dedicada ainda: uma caixa vazia simples.
    empty_list: <<~SVG
      <circle cx="48" cy="48" r="46" fill="var(--dt-petrol-100)"/>
      <path d="M26 44l22-12 22 12-22 12-22-12Z" fill="var(--dt-ice-0)" stroke="var(--dt-petrol-500)" stroke-width="2" stroke-linejoin="round"/>
      <path d="M26 44v18l22 12 22-12V44" fill="none" stroke="var(--dt-petrol-500)" stroke-width="2" stroke-linejoin="round"/>
      <path d="M48 56v18" stroke="var(--dt-petrol-500)" stroke-width="2"/>
    SVG
  }.freeze

  # Devolve o `<svg>` da ilustração `name`, pronta para colocar dentro de um
  # `.empty-state` (ver `design_components.css`) junto com título e texto.
  def empty_state_illustration(name, size: 144)
    body = ILLUSTRATIONS.fetch(name) { raise ArgumentError, "ilustração desconhecida: #{name.inspect}" }

    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" width="#{size}" height="#{size}" aria-hidden="true" role="img">
        #{body}
      </svg>
    SVG

    svg.html_safe # rubocop:disable Rails/OutputSafety -- markup fixo, vem só de ILLUSTRATIONS.
  end
end
