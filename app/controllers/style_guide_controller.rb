# frozen_string_literal: true

# A vitrine da fundação visual: tokens, componentes, ícones e ilustrações da
# fase 1 do redesign, lado a lado, para aprovação visual antes de qualquer
# tela real ser tocada.
#
# Herda de `ActionController::Base`, e não de `ApplicationController`, pelo
# mesmo motivo do `BarbershopsController`: o `around_action
# :use_current_barbershop` do pai levanta `RecordNotFound` quando não há
# tenant, e esta página não pertence a nenhuma barbearia — ela é ferramenta
# de quem constrói a tela, não conteúdo de cliente. Herdar do pai
# transformaria a vitrine num 404.
#
# A rota só é desenhada fora de produção (`config/routes.rb`), mas o
# controller confere de novo: uma rota que algum dia vazasse para produção
# por engano não deveria, ainda assim, abrir a página.
class StyleGuideController < ActionController::Base # rubocop:disable Rails/ApplicationController
  layout "style_guide"

  def index
    raise ActiveRecord::RecordNotFound if Rails.env.production?
  end
end
