class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # A borda do tenant. Todo request passa por aqui, e é aqui que Current passa
  # a existir: sem isto, nenhuma query escopada devolve nada e a aplicação
  # responde 200 sem conteúdo.
  #
  # O `ensure` existe para o caso de exceção dentro da requisição, e não
  # substitui o RequestStore: quem garante a limpeza no caminho normal é o
  # middleware, no fechamento do body. Os dois juntos cobrem os dois caminhos.
  around_action :use_current_barbershop

  protected

  def after_sign_in_path_for(resource)
    resource.admin? ? admin_root_path : root_path
  end

  private

  def use_current_barbershop
    Current.barbershop = resolve_barbershop
    raise ActiveRecord::RecordNotFound if Current.barbershop.nil?

    yield
  ensure
    Current.reset
  end

  def resolve_barbershop
    SubdomainResolver.new(request.host_with_port).call
  end
end
