module ConfirmationPathFilter
  CONFIRMATION_PATH = %r{(/appointments/confirmation/)[^/?#]+}

  def filtered_path
    super.gsub(CONFIRMATION_PATH, "\\1[FILTERED]")
  end
end

ActiveSupport.on_load(:action_dispatch_request) { prepend ConfirmationPathFilter }
