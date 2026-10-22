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
end
