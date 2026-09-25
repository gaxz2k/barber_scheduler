require 'rails_helper'

# rubocop:disable RSpec/DescribeClass, RSpec/ExampleLength
RSpec.describe "parameter filtering" do
  it "filters public booking visitor name and phone" do
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(
      "appointment" => { "client_name" => "Maria da Silva", "client_phone" => "(19) 99999-8888" }
    )

    expect(filtered.fetch("appointment")).to include(
      "client_name" => "[FILTERED]", "client_phone" => "[FILTERED]"
    )
  end
end
# rubocop:enable RSpec/DescribeClass, RSpec/ExampleLength
