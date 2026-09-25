require "rails_helper"

# SEC-003: the public booking form posts :client_name and :client_phone, but
# PublicScheduler persists into the clients table columns name/phone, and the
# ActiveRecord SQL log binds were written in cleartext. The bind values the
# subscriber filters never reach the SQL payload (it carries $1/$2
# placeholders); they are rendered into the log line. So the log line is the
# only place the masking is observable, which is why this drives a real
# unauthenticated POST rather than a bare Client.create!.
RSpec.describe "Visitor data in the SQL log", type: :request do
  let(:visitor_name) { "Joana Souza Ribeiro" }
  let(:visitor_phone) { "11988887777" }

  def book_publicly
    professional = Professional.create!(name: "Profissional Log")
    service = Service.create!(name: "Corte Log", duration_minutes: 30)
    start_at = 2.days.from_now.change(hour: 10, min: 0, sec: 0)
    post appointments_path, params: {
      appointment: {
        service_id: service.id, professional_id: professional.id,
        date: start_at.to_date.iso8601, start_at: start_at.iso8601,
        client_name: visitor_name, client_phone: visitor_phone
      }
    }
  end

  # Captures the lines the log subscriber builds, at DEBUG so the sql event is
  # emitted, and restores the original logger afterwards.
  def capture_sql_log
    io = StringIO.new
    original_logger = ActiveRecord::Base.logger
    original_level = original_logger&.level
    ActiveRecord::Base.logger = Logger.new(io).tap { |logger| logger.level = Logger::DEBUG }
    yield
    io.string
  ensure
    ActiveRecord::Base.logger&.level = original_level
    ActiveRecord::Base.logger = original_logger
  end

  it "keeps the visitor's name and phone out of the SQL log" do
    output = capture_sql_log { book_publicly }
    leaked = [ output.include?(visitor_name), output.include?(visitor_phone), output.include?(visitor_phone[4..]) ]

    expect(leaked).to eq([ false, false, false ])
  end

  it "records the SQL statement itself, so the assertion above is not vacuous" do
    output = capture_sql_log { book_publicly }

    expect(output).to include('INSERT INTO "clients"')
  end

  it "still creates the appointment, so the log was actually exercised" do
    capture_sql_log { book_publicly }

    expect(Appointment.last.client.name).to eq(visitor_name)
  end
end
