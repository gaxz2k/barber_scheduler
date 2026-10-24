module ApplicationHelper
  # Mapeia o status de agendamento (`Appointment#status`) para a variante do
  # `.badge` da fundação visual. Fica aqui, e não repetido em cada view, porque
  # o admin (listagem e detalhe) e qualquer tela futura que mostrar status
  # precisam da mesma cor para o mesmo estado — ver o comentário em
  # `design_tokens.css` sobre a paleta de status seguir o símbolo universal.
  STATUS_BADGE_VARIANTS = {
    "pending" => "warning",
    "confirmed" => "success",
    "canceled" => "danger",
    "completed" => "neutral"
  }.freeze

  def status_badge_class(status)
    "badge badge--#{STATUS_BADGE_VARIANTS.fetch(status.to_s, 'neutral')}"
  end
end
