# frozen_string_literal: true

require "test_helper"

class ReplyWhatsappMessageTest < ActiveSupport::TestCase
  test "START asks for the business card each time" do
    user = users(:lazaro_nixon)
    user.update!(whatsapp_phone: "15551234567")
    sent = []

    original = WhatsappCloud.method(:send_text)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args }

    ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: "START"))
    ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: " start "))

    assert_equal [ { phone_number_id: "1369590492903246", to: "15551234567", body: WhatsappOnboarding::MESSAGES["business_card"] } ] * 2, sent
    assert_equal "business_card", user.reload.whatsapp_pending_question
  ensure
    WhatsappCloud.define_singleton_method(:send_text, original)
  end

  test "text from an unknown phone creates a user and starts onboarding" do
    sent = []

    original = WhatsappCloud.method(:send_text)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args[:body] }

    assert_difference -> { User.count }, 1 do
      ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: "Hey"))
    end

    user = User.find_by!(whatsapp_phone: "15551234567")
    assert_equal [ WhatsappOnboarding::MESSAGES["business_card"] ], sent
    assert_equal "business_card", user.whatsapp_pending_question
  ensure
    WhatsappCloud.define_singleton_method(:send_text, original)
  end

  test "brand voice button saves the voice and asks for email, then email finishes onboarding" do
    user = users(:lazaro_nixon)
    user.update!(whatsapp_phone: "15551234567", whatsapp_pending_question: "brand_voice", email: nil)
    sent = []
    reactions = []

    original_send = WhatsappCloud.method(:send_text)
    original_react = WhatsappCloud.method(:react)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args[:body] }
    WhatsappCloud.define_singleton_method(:react) { |**args| reactions << args }

    ReplyWhatsappMessage.call(button_payload(from: "15551234567", id: "bold"))
    assert_equal "bold", user.reload.brand_voice
    assert_equal "email", user.whatsapp_pending_question
    assert_equal [ WhatsappOnboarding::MESSAGES["email"] ], sent

    ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: "not an email"))
    assert_equal "email", user.reload.whatsapp_pending_question
    assert_equal [ WhatsappOnboarding::MESSAGES["email"] ] * 2, sent

    users(:admin_user).update!(email: "taken@cuts.example")
    ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: "taken@cuts.example"))
    assert_equal "email", user.reload.whatsapp_pending_question
    assert_nil user.email
    assert_equal "That email is already on another Rocketbox account. Send a different one.", sent.last

    ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: " Ada@Cuts.example "))
    user.reload
    assert_equal "ada@cuts.example", user.email
    assert_nil user.whatsapp_pending_question
    assert_equal 1, reactions.size
  ensure
    WhatsappCloud.define_singleton_method(:send_text, original_send)
    WhatsappCloud.define_singleton_method(:react, original_react)
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
    assert_equal [ { phone_number_id: "1369590492903246", to: "15551234567", message_id: "wamid.text" } ] * 2, reactions
    assert_empty sent
  ensure
    WhatsappCloud.define_singleton_method(:react, original_react)
    WhatsappCloud.define_singleton_method(:send_text, original_send)
  end

  test "approval button approves a waiting run owned by the sender" do
    user = users(:lazaro_nixon)
    user.update!(whatsapp_phone: "15551234567")
    photo = user.library_media.create!(kind: "photo", folder: folders(:interior),
      file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    run = Transformation.create!(name: "Approval", kind: "approval").run!(items: [ photo ], folder: folders(:ready))
    assert_equal "waiting", run.status

    sent = []
    reactions = []
    original_send = WhatsappCloud.method(:send_text)
    original_react = WhatsappCloud.method(:react)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args[:body] }
    WhatsappCloud.define_singleton_method(:react) { |**args| reactions << args }

    ReplyWhatsappMessage.call(button_payload(from: "15551234567", id: "approval:approve:#{run.id}"))

    assert_equal "complete", run.reload.status
    assert_equal [ "Approved — continuing." ], sent
    assert_equal 1, reactions.size
  ensure
    WhatsappCloud.define_singleton_method(:send_text, original_send) if original_send
    WhatsappCloud.define_singleton_method(:react, original_react) if original_react
  end

  test "approval reject stops a waiting run" do
    user = users(:lazaro_nixon)
    user.update!(whatsapp_phone: "15551234567")
    photo = user.library_media.create!(kind: "photo", folder: folders(:interior),
      file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    run = Transformation.create!(name: "Approval", kind: "approval").run!(items: [ photo ], folder: folders(:ready))
    sent = []
    original_send = WhatsappCloud.method(:send_text)
    original_react = WhatsappCloud.method(:react)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args[:body] }
    WhatsappCloud.define_singleton_method(:react) { |_| }

    ReplyWhatsappMessage.call(button_payload(from: "15551234567", id: "approval:reject:#{run.id}"))

    assert_equal "rejected", run.reload.status
    assert_equal [ "Rejected — won't post this one." ], sent
  ensure
    WhatsappCloud.define_singleton_method(:send_text, original_send) if original_send
    WhatsappCloud.define_singleton_method(:react, original_react) if original_react
  end

  test "stale approval button gets a short reply" do
    user = users(:lazaro_nixon)
    user.update!(whatsapp_phone: "15551234567")
    sent = []
    original_send = WhatsappCloud.method(:send_text)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args[:body] }

    ReplyWhatsappMessage.call(button_payload(from: "15551234567", id: "approval:approve:999999"))

    assert_equal [ "That approval is no longer pending." ], sent
  ensure
    WhatsappCloud.define_singleton_method(:send_text, original_send)
  end

  private

    def text_payload(from:, body:)
      message_payload("from" => from, "id" => "wamid.text", "type" => "text", "text" => { "body" => body })
    end

    def button_payload(from:, id:)
      message_payload("from" => from, "id" => "wamid.button", "type" => "interactive",
        "interactive" => { "type" => "button_reply", "button_reply" => { "id" => id, "title" => id.capitalize } })
    end

    def message_payload(message)
      {
        "entry" => [ {
          "changes" => [ {
            "field" => "messages",
            "value" => {
              "metadata" => { "phone_number_id" => "1369590492903246" },
              "messages" => [ message ]
            }
          } ]
        } ]
      }
    end
end
