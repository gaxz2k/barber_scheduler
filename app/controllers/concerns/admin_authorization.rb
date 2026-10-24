module AdminAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    before_action :require_admin!
  end

  private

  # Duas checagens, e a segunda é a que faltava: `admin?` sozinho deixava um
  # administrador da loja A entrar no painel da loja B, porque a flag não diz a
  # qual loja ele pertence. `Current.barbershop` já está resolvido quando esta
  # concern roda — o `around_action` de `ApplicationController` roda antes de
  # qualquer `before_action` do controller —, então a comparação é com a loja
  # que a requisição está servindo, não com a que o usuário criou.
  #
  # As duas rejeições são indistintas de propósito: dizer "você não é admin"
  # a quem é admin de outra loja entrega a existência do painel. O mesmo
  # `alert` para os dois casos.
  def require_admin!
    return if current_user&.admin? && current_user.atende_esta_barbershop?(Current.barbershop)

    redirect_to root_path, alert: t("admin_authorization.restricted")
  end
end
