# frozen_string_literal: true

require "test_helper"

class WhatsappCloudTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @user.update!(whatsapp_phone: "15551234567")
    @original = WhatsappCloud.method(:request!)
  end

  teardown { WhatsappCloud.define_singleton_method(:request!, @original) }

  test "sent message is stored" do
    WhatsappCloud.define_singleton_method(:request!) { |*| { "messages" => [ { "id" => "wamid.1" } ] } }

    WhatsappCloud.send_cta_url(phone_number_id: "1", to: "15551234567", body: "Tap", display_text: "Go", url: "https://x.test/login")

    message = OutgoingMessage.last
    assert_equal [ "whatsapp", "interactive", "Tap", "wamid.1", "15551234567", @user, nil ],
                 [ message.channel, message.kind, message.body, message.external_id, message.recipient, message.user, message.error ]
    assert_equal "https://x.test/login", message.payload.dig("interactive", "action", "parameters", "url")
  end

  test "failed send is stored with the error and re-raised" do
    WhatsappCloud.define_singleton_method(:request!) { |*| raise WhatsappCloud::Error, "outside 24h window" }

    assert_raises(WhatsappCloud::Error) { WhatsappCloud.send_text(phone_number_id: "1", to: "15551234567", body: "Hi") }

    message = OutgoingMessage.last
    assert_equal [ "text", "Hi", nil ], [ message.kind, message.body, message.external_id ]
    assert_equal "WhatsappCloud::Error: outside 24h window", message.error
  end
end
