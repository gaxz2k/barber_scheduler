class ShopSetting < ApplicationRecord
  include TenantScoped
  apply_tenant_scope

  validates :barbershop_id, uniqueness: true
end
