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
  end

  test "business brief is complete when every field and the logo are set" do
    user = users(:lazaro_nixon)
    user.update!(
      business_name: "Acme", phone: "1", name: "Ada", address: "1 High St",
      homepage_url: "https://acme.test", business_description: "Cuts", business_hours: "9-5"
    )
    logo = user.library_media.create!(kind: "photo", folder: Folder.logo)
    logo.file.attach(io: StringIO.new("logo"), filename: "logo.png", content_type: "image/png")

    assert_includes RocketboxAgent.business_brief(user), "Onboarding: COMPLETE"
  end

  test "reply forgets the previous turn and restates an incomplete brief" do
    user = users(:lazaro_nixon)
    user.update!(phone: nil, name: nil, address: nil, homepage_url: nil, business_description: nil, business_hours: nil)
    chat = user.create_chat!
    chat.messages.create!(role: "user", content: "secret previous turn")
    seen = []
    original = Chat.instance_method(:ask)
    Chat.define_method(:ask) do |message = nil, **|
      seen << to_llm.messages.map { |m| "#{m.role} #{m.content}" }.join("\n")
      Struct.new(:content).new("What is your phone number?")
    end

    assert_no_difference -> { Chat.where(user:).count } do
      RocketboxAgent.reply(user, "hello")
      chat.messages.create!(role: "user", content: "hello from before")
      RocketboxAgent.reply(user, "second")
    end

    assert_equal 2, seen.size
    assert_includes seen[0], "Onboarding: INCOMPLETE"
    assert_not_includes seen[0], "secret previous turn"
    assert_not_includes seen[1], "hello from before"
    assert_not_includes seen[1], "secret previous turn"
  ensure
    Chat.define_method(:ask, original) if original
  end
end
