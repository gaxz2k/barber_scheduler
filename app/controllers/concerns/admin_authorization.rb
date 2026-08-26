module AdminAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    before_action :require_admin!
  end

  private

  def require_admin!
    redirect_to root_path, alert: "Acesso restrito." unless current_user.admin?
  end
end
