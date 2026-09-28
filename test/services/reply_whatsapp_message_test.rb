# frozen_string_literal: true

require "test_helper"

class ReplyWhatsappMessageTest < ActiveSupport::TestCase
  test "START sends a welcome each time" do
    sent = []

    original = WhatsappCloud.method(:send_text)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args }

    ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: "START"))
    ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: " start "))

    assert_equal [ { phone_number_id: "1238456642695224", to: "15551234567", body: ReplyWhatsappMessage::WELCOME } ] * 2, sent
  ensure
    WhatsappCloud.define_singleton_method(:send_text, original)
  end

  test "reply to a pending question is saved to that field" do
    user = users(:lazaro_nixon)
    user.update!(whatsapp_phone: "15551234567", whatsapp_pending_question: "business_name")
    reactions = []

    original = WhatsappCloud.method(:react)
    WhatsappCloud.define_singleton_method(:react) { |**args| reactions << args }

    ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: " Ada Cuts "))

    user.reload
    assert_equal "Ada Cuts", user.business_name
    assert_nil user.whatsapp_pending_question
    assert_equal 1, reactions.size
  ensure
    WhatsappCloud.define_singleton_method(:react, original)
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
    assert_equal [ { phone_number_id: "1238456642695224", to: "15551234567", message_id: "wamid.text" } ] * 2, reactions
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
              "metadata" => { "phone_number_id" => "1238456642695224" },
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
