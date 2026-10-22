# frozen_string_literal: true

require "test_helper"

class Accounts::WhatsappControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
    @user.update!(whatsapp_phone: "15551234567")
  end

  test "shows this account's thread, including a message stored before the user existed" do
    IncomingMessage.create!(channel: "whatsapp", user: nil, sender: "15551234567", external_id: "wamid.first",
      kind: "text", body: "first text", payload: { "id" => "wamid.first" })
    incoming = IncomingMessage.create!(channel: "whatsapp", user: @user, sender: "15551234567", external_id: "wamid.in",
      kind: "interactive", body: nil, payload: { "interactive" => { "button_reply" => { "title" => "Classic" } } })
    photo = IncomingMessage.create!(channel: "whatsapp", user: @user, sender: "15551234567", external_id: "wamid.photo",
      kind: "image", body: "", payload: { "id" => "wamid.photo", "type" => "image" })
    photo.attachments.attach(io: StringIO.new("img"), filename: "cut.jpg", content_type: "image/jpeg")
    OutgoingMessage.create!(channel: "whatsapp", user: @user, recipient: "15551234567", external_id: "wamid.out",
      kind: "interactive", body: "Pick a voice", payload: { "interactive" => { "action" => { "buttons" => [ { "reply" => { "title" => "Bold" } } ] } } })
    OutgoingMessage.create!(channel: "whatsapp", user: @user, recipient: "15551234567", kind: "reaction", body: "🦄",
      payload: { "reaction" => { "message_id" => incoming.external_id, "emoji" => "🦄" } })
    IncomingMessage.create!(channel: "whatsapp", user: users(:admin_user), sender: "1999", kind: "text",
      body: "secret other chat", payload: { "id" => "wamid.other" })

    get whatsapp_url

    assert_response :success
    assert_match "first text", response.body
    assert_select "section[aria-label='WhatsApp chat'] img"
    assert_match "Classic", response.body
    assert_match "Pick a voice", response.body
    assert_match "Bold", response.body
    assert_equal 1, response.body.scan("🦄").size
    assert_no_match "secret other chat", response.body
    assert_select "a[href^=?]", admin_incoming_message_path(incoming), count: 0
  end

  test "admin sees a link to each message" do
    admin = sign_in_as(users(:admin_user))
    admin.update!(whatsapp_phone: "15550000001")
    incoming = IncomingMessage.create!(channel: "whatsapp", user: admin, sender: "15550000001", external_id: "wamid.admin-in",
      kind: "text", body: "from the shop", payload: { "id" => "wamid.admin-in" })
    outgoing = OutgoingMessage.create!(channel: "whatsapp", user: admin, recipient: "15550000001", external_id: "wamid.admin-out",
      kind: "text", body: "from rocketbox", payload: { "type" => "text" })

    get whatsapp_url(account: admin.id)

    assert_response :success
    assert_select "a[href^=?]", admin_incoming_message_path(incoming), text: "Admin"
    assert_select "a[href^=?]", admin_outgoing_message_path(outgoing), text: "Admin"
  end

  test "text from the composer is an incoming message and gets the agent reply" do
    original_request = WhatsappCloud.method(:request!)
    original_reply = RocketboxAgent.method(:reply)
    WhatsappCloud.define_singleton_method(:request!) { |*| { "messages" => [ { "id" => "wamid.dash-reply" } ] } }
    RocketboxAgent.define_singleton_method(:reply) { |*| Struct.new(:content).new("What's the business called?") }

    assert_difference -> { IncomingMessage.where(channel: "whatsapp", kind: "text").count }, 1 do
      post whatsapp_url, params: { body: "hello from the desk" }
    end

    incoming = IncomingMessage.find_by!(channel: "whatsapp", body: "hello from the desk")
    assert_equal @user, incoming.user
    assert_equal "15551234567", incoming.sender
    assert_redirected_to whatsapp_url

    follow_redirect!
    assert_select "p", text: "hello from the desk"
    assert_select "p", text: "What's the business called?"
  ensure
    WhatsappCloud.define_singleton_method(:request!, original_request)
    RocketboxAgent.define_singleton_method(:reply, original_reply)
  end

  test "an attachment is one incoming message and inbox media, with no agent reply" do
    replies = 0
    original_reply = RocketboxAgent.method(:reply)
    RocketboxAgent.define_singleton_method(:reply) { |*| replies += 1 }

    assert_no_difference -> { OutgoingMessage.count } do
      assert_difference -> { LibraryMedia.count }, 1 do
        post whatsapp_url, params: { body: "fresh cut", attachments: [ fixture_file_upload("rendered.jpg", "image/jpeg") ] }
      end
    end

    incoming = IncomingMessage.order(:id).last
    media = LibraryMedia.order(:id).last
    assert_equal "image", incoming.kind
    assert_equal "fresh cut", incoming.body
    assert incoming.attachments.attached?
    assert_equal media.file.blob, incoming.attachments.first.blob
    assert_equal folders(:inbox), media.folder
    assert_equal @user, media.user
    assert_equal 0, replies
  ensure
    RocketboxAgent.define_singleton_method(:reply, original_reply)
  end

  test "an empty composer post creates nothing" do
    assert_no_difference -> { IncomingMessage.count } do
      post whatsapp_url, params: { body: "  " }
    end

    assert_redirected_to whatsapp_url
  end
end
