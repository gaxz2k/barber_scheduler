# frozen_string_literal: true

# Mapeia o `tom` que o servidor calcula (ver `Admin::DashboardMetrics`) para
# a classe de badge/indicador correspondente em `design_components.css`.
#
# Fica num helper, e não espalhado em `case` dentro de cada view, porque o
# mapeamento tom -> aparência é único: se um indicador novo usar um tom fora
# da lista, o `fetch` com bloco abaixo avisa alto (erro), em vez de a view
# silenciosamente não pintar nada.
module DashboardToneHelper
  TOM_BADGE_CLASS = {
    "ok" => "badge--success",
    "atencao" => "badge--warning",
    "critico" => "badge--danger",
    "neutro" => "badge--neutral",
    "sem_dado" => "badge--neutral"
  }.freeze

  TOM_CARD_CLASS = {
    "ok" => "metric-card--ok",
    "atencao" => "metric-card--atencao",
    "critico" => "metric-card--critico",
    "neutro" => "metric-card--neutro",
    "sem_dado" => "metric-card--neutro"
  }.freeze

  def tom_badge_class(tom)
    TOM_BADGE_CLASS.fetch(tom) { raise ArgumentError, "tom desconhecido: #{tom.inspect}" }
  end

  def tom_card_class(tom)
    TOM_CARD_CLASS.fetch(tom) { raise ArgumentError, "tom desconhecido: #{tom.inspect}" }
  end
end
