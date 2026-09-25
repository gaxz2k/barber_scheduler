require 'rails_helper'

RSpec.describe Client, type: :model do
  it "is a valid client" do
    client = described_class.new(phone: "123-456-7890", name: "John Doe")
    expect(client).to be_valid
  end

  it "is invalid without a phone number" do
    client = described_class.new(phone: nil)
    expect(client).not_to be_valid
  end

  it "is invalid without a name" do
    client = described_class.new(name: nil)
    expect(client).not_to be_valid
  end

  it "filters personal data out of the SQL log" do
    result = described_class.filter_attributes.map(&:to_s)

    expect(result).to include("name", "phone")
  end

  it "does not write the name or phone of a new client to the SQL log" do
    output = capture_sql_log { described_class.create!(name: "Visitante Teste", phone: "19999998888") }
    result = [ output.include?("Visitante Teste"), output.include?("19999998888") ]

    expect(result).to eq([ false, false ])
  end

  def capture_sql_log
    io = StringIO.new
    original_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = Logger.new(io).tap { |logger| logger.level = Logger::DEBUG }
    ActiveSupport::Notifications.subscribed(
      ->(_name, _start, _finish, _id, payload) { io.write(payload[:sql].to_s) if payload[:name] == "SQL" },
      "sql.active_record"
    ) { yield }
    io.string
  ensure
    ActiveRecord::Base.logger = original_logger
  end
end
