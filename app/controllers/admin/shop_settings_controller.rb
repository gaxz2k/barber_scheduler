class Admin::ShopSettingsController < Admin::BaseController
  before_action :set_shop_setting

  def edit
  end

  def update
    if @shop_setting.update(shop_setting_params)
      redirect_to edit_admin_shop_setting_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  # A barbearia tem no máximo uma configuração, e a tela sempre edita a dela
  # — não existe lista nem busca por id. `find_or_initialize_by` cria a linha
  # na primeira visita sem exigir uma migration de backfill para barbearias
  # que já existiam antes desta feature.
  def set_shop_setting
    @shop_setting = Current.barbershop.shop_setting || Current.barbershop.build_shop_setting
  end

  def shop_setting_params
    params.expect(shop_setting: [ :online_booking_enabled, :online_booking_message, :collect_cpf ])
  end
end
