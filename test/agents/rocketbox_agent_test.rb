# frozen_string_literal: true

require "test_helper"

class RocketboxAgentTest < ActiveSupport::TestCase
  test "business brief shows the set name and missing fields" do
    user = users(:lazaro_nixon)
    user.update!(
      business_name: "Wick Lane Barbershop",
      phone: nil, name: nil, address: nil, homepage_url: nil,
      business_description: nil, business_hours: nil
    )

    brief = RocketboxAgent.business_brief(user)

    assert_includes brief, "Onboarding: INCOMPLETE"
    assert_includes brief, "Business name: Wick Lane Barbershop"
    assert_includes brief, "Phone: (missing)"
    assert_includes brief, "Contact name: (missing)"
    assert_includes brief, "Address: (missing)"
    assert_includes brief, "Website: (missing)"
    assert_includes brief, "Description: (missing)"
    assert_includes brief, "Hours: (missing)"
    assert_includes brief, "Logo: (missing)"
    assert_includes brief, "WhatsApp: (missing)"
    assert_includes brief, "Instagram: (missing)"
  end

  test "business brief is complete when every field and the logo are set" do
    user = users(:lazaro_nixon)
    user.update!(
      business_name: "Acme", phone: "1", name: "Ada", address: "1 High St",
      homepage_url: "https://acme.test", business_description: "Cuts", business_hours: "9-5",
      whatsapp_phone: "15551234567", instagram_user_id: "ig", instagram_access_token: "token"
    )
    logo = user.library_media.create!(kind: "photo", folder: Folder.logo)
    logo.file.attach(io: StringIO.new("logo"), filename: "logo.png", content_type: "image/png")

    assert_includes RocketboxAgent.business_brief(user), "Onboarding: COMPLETE"
  end

  test "business brief stays incomplete without instagram" do
    user = users(:lazaro_nixon)
    user.update!(
      business_name: "Acme", phone: "1", name: "Ada", address: "1 High St",
      homepage_url: "https://acme.test", business_description: "Cuts", business_hours: "9-5",
      whatsapp_phone: "15551234567"
    )
    logo = user.library_media.create!(kind: "photo", folder: Folder.logo)
    logo.file.attach(io: StringIO.new("logo"), filename: "logo.png", content_type: "image/png")

    brief = RocketboxAgent.business_brief(user)

    assert_includes brief, "Onboarding: INCOMPLETE"
    assert_includes brief, "WhatsApp: connected"
    assert_includes brief, "Instagram: (missing)"
  end

  test "system messages are the instructions and then the brief" do
    user = users(:lazaro_nixon)
    user.update!(
      business_name: "Wick Lane Barbershop",
      phone: nil, name: nil, address: nil, homepage_url: nil,
      business_description: nil, business_hours: nil
    )

    messages = RocketboxAgent.system_messages(user)

    assert_equal 2, messages.size
    assert_includes messages[0], "You cannot see the image"
    assert_includes messages[0], "When onboarding is COMPLETE, ask them to send photos of their work"
    assert_includes messages[0], "At least 2 photos are needed to compose the first Instagram reel"
    assert_includes messages[1], "Onboarding: INCOMPLETE"
    assert_includes messages[1], "Business name: Wick Lane Barbershop"
  end

  test "reply forgets a chat-only message and replays an incoming one" do
    user = users(:lazaro_nixon)
    user.update!(phone: nil, name: nil, address: nil, homepage_url: nil, business_description: nil, business_hours: nil)
    chat = user.create_chat!
    chat.messages.create!(role: "user", content: "secret previous turn")
    IncomingMessage.create!(channel: "whatsapp", user:, kind: "text", body: "hello from them", payload: { "id" => "wamid.hello" })
    seen = []
    original = Chat.instance_method(:complete)
    Chat.define_method(:complete) do |*|
      seen << to_llm.messages.map { |m| "#{m.role} #{m.content}" }.join("\n")
      Struct.new(:content).new("What is your phone number?")
    end

    assert_no_difference -> { Chat.where(user:).count } do
      RocketboxAgent.reply(user, "second")
    end

    assert_equal 1, seen.size
    assert_includes seen[0], "Onboarding: INCOMPLETE"
    assert_includes seen[0], "hello from them"
    assert_includes seen[0], "second"
    assert_not_includes seen[0], "secret previous turn"
  ensure
    Chat.define_method(:complete, original) if original
  end
end
