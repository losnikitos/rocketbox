# frozen_string_literal: true

require "test_helper"

class ProcessWhatsappUpdateJobTest < ActiveJob::TestCase
  test "any message from a new number creates a user once" do
    payload = {
      "entry" => [ {
        "changes" => [ {
          "field" => "messages",
          "value" => { "messages" => [ { "from" => "15551234567", "id" => "wamid.loc", "type" => "location" } ] }
        } ]
      } ]
    }

    assert_difference -> { User.count }, 1 do
      2.times { ProcessWhatsappUpdateJob.perform_now(payload) }
    end

    user = User.find_by!(whatsapp_phone: "15551234567")
    assert_nil user.email
    assert_equal [ user ], IncomingMessage.where(sender: "15551234567").map(&:user).uniq
  end
end
