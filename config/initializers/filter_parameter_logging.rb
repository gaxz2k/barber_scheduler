# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_redirect += [ %r{/appointments/confirmation/} ]
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :client_name, :client_phone
]

# The public booking form posts :client_name and :client_phone, but
# PublicScheduler persists into the clients table columns name/phone, so the
# ActiveRecord SQL log binds were written in cleartext.
#
# The log subscriber hands the BARE column name to the filter
# (ActiveRecord::LogSubscriber#filter -> inspection_filter.filter_param) and
# passes no model context, so these must be declared as bare column names: a
# qualified "client.name" never matches, and a per-model filter_attributes
# declaration never reaches the log, because the subscriber reads
# ActiveRecord::Base.inspection_filter. That is also why the keys live here
# rather than in the Client model.
#
# Bare strings are deliberate rather than a Proc: a Proc keyed on the exact
# name matches less. These string keys compile to unanchored regexes, so they
# also mask columns such as active_storage_blobs.filename and service_name,
# and they apply to the request Parameters: line as well as the SQL log. That
# is over-redaction, not a leak, and it is the safer direction.
Rails.application.config.filter_parameters += [ "name", "phone" ]
