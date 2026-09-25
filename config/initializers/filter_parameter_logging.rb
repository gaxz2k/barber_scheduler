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
# ActiveRecord SQL log binds were written in cleartext. The log subscriber
# passes the bare column name to the filter (ActiveRecord::LogSubscriber#filter
# -> inspection_filter.filter_param(attribute_name, value)), so these must be
# declared as bare column names, not "client.name": a qualified key never
# matches. The names are declared globally because the subscriber hardcodes
# ActiveRecord::Base.inspection_filter and cannot see a per-model list.
Rails.application.config.filter_parameters += [ "name", "phone" ]
