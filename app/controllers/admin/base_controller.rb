class Admin::BaseController < ApplicationController
  include AdminAuthorization
  layout "admin"
end
