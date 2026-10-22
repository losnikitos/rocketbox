# frozen_string_literal: true

require "test_helper"

class ReplyWhatsappMessageTest < ActiveSupport::TestCase
  test "START and any other text are answered by the agent" do
    user = users(:lazaro_nixon)
    user.update!(whatsapp_phone: "15551234567")
    sent = []

    original = WhatsappCloud.method(:send_text)
    original_reply = RocketboxAgent.method(:reply)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args }
    RocketboxAgent.define_singleton_method(:reply) { |*| Struct.new(:content).new("What's the business called?") }

    ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: "START"))
    ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: " start "))

    assert_equal [ { phone_number_id: "1369590492903246", to: "15551234567", body: "What's the business called?" } ] * 2, sent
    assert_nil user.reload.whatsapp_pending_question
  ensure
    WhatsappCloud.define_singleton_method(:send_text, original)
    RocketboxAgent.define_singleton_method(:reply, original_reply)
  end

  test "text from an unknown phone creates a user and asks the agent" do
    sent = []

    original = WhatsappCloud.method(:send_text)
    original_reply = RocketboxAgent.method(:reply)
    WhatsappCloud.define_singleton_method(:send_text) { |**args| sent << args[:body] }
    RocketboxAgent.define_singleton_method(:reply) { |*| Struct.new(:content).new("What's the business called?") }

    assert_difference -> { User.count }, 1 do
      ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: "Hey"))
    end

    user = User.find_by!(whatsapp_phone: "15551234567")
    assert_equal [ "What's the business called?" ], sent
    assert_nil user.whatsapp_pending_question
  ensure
    WhatsappCloud.define_singleton_method(:send_text, original)
    RocketboxAgent.define_singleton_method(:reply, original_reply)
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
    assert_empty sent
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

  test "text while a step is waiting resends it and does not ask the assistant" do
    user = users(:lazaro_nixon)
    user.update!(whatsapp_phone: "15551234567")
    photo = user.library_media.create!(kind: "photo", folder: folders(:interior),
      file: { io: StringIO.new("img"), filename: "a.jpg", content_type: "image/jpeg" })
    buttons = []
    original = WhatsappCloud.method(:send_buttons)
    WhatsappCloud.define_singleton_method(:send_buttons) { |**args| buttons << args }
    run = Transformation.create!(name: "Approval", kind: "approval", body: "Your reel is ready. Publish?",
      options: { "button" => "Publish" }).run!(items: [ photo ], folder: folders(:ready))

    assert_no_difference -> { Chat.count } do
      ReplyWhatsappMessage.call(text_payload(from: "15551234567", body: "hello"))
    end

    assert_equal "waiting", run.reload.status
    assert_equal [ "Your reel is ready. Publish?" ] * 2, buttons.map { it[:body] }
    assert_equal({ "approval:approve:#{run.id}" => "Publish" }, buttons.last[:buttons])
  ensure
    WhatsappCloud.define_singleton_method(:send_buttons, original) if original
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
