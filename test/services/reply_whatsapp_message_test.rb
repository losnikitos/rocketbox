# frozen_string_literal: true

require "test_helper"

class ReplyWhatsappMessageTest < ActiveSupport::TestCase
  test "START_<code> links the sender's phone and sends a welcome" do
    user = users(:lazaro_nixon)
    code = user.whatsapp_connect_code!
    sent = []

    original = WhatsappCloud.method(:send_text)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args }

    ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: "START_#{code}"))

    user.reload
    assert_equal "15551234567", user.whatsapp_phone
    assert_nil user.whatsapp_connect_code
    assert_equal [ { to: "15551234567", body: "Welcome to Rocketbox 👋\nYour account is connected." } ], sent
  ensure
    WhatsappCloud.define_singleton_method(:send_text, original)
  end

  test "START_<code> from an already linked phone re-sends the welcome" do
    users(:lazaro_nixon).update!(whatsapp_phone: "15551234567", whatsapp_connect_code: nil)
    sent = []

    original = WhatsappCloud.method(:send_text)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args }

    ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: "START_usedcode"))

    assert_equal [ { to: "15551234567", body: "Welcome to Rocketbox 👋\nYour account is connected." } ], sent
  ensure
    WhatsappCloud.define_singleton_method(:send_text, original)
  end

  test "urls from a linked phone are saved to links with a reaction and no reply" do
    user = users(:lazaro_nixon)
    user.update!(whatsapp_phone: "15551234567")
    reactions = []
    sent = []

    original_react = WhatsappCloud.method(:react)
    original_send = WhatsappCloud.method(:send_text)
    WhatsappCloud.define_singleton_method(:react) { |**args| reactions << args }
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args }

    2.times { ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: "check https://trustpilot.com/review/x.")) }

    assert_equal [ [ "https://trustpilot.com/review/x", "whatsapp" ] ], user.links.pluck(:url, :source)
    assert_equal [ { to: "15551234567", message_id: "wamid.text" } ] * 2, reactions
    assert_empty sent
  ensure
    WhatsappCloud.define_singleton_method(:react, original_react)
    WhatsappCloud.define_singleton_method(:send_text, original_send)
  end

  private

    def text_payload(from:, body:)
      {
        "entry" => [ {
          "changes" => [ {
            "field" => "messages",
            "value" => {
              "messages" => [ {
                "from" => from,
                "id" => "wamid.text",
                "type" => "text",
                "text" => { "body" => body }
              } ]
            }
          } ]
        } ]
      }
    end
end
