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

  test "admin sees workflow runs in the thread; the owner does not" do
    photo = @user.library_media.create!(kind: "photo", folder: folders(:business_card))
    workflow = Workflow.create!(name: "Card filing")
    run = workflow.runs.create!(status: "started", picks: { "9" => [ photo.id ] })
    step = run.step_runs.create!(result: photo, status: "complete")
    step.inputs.create!(item: photo, position: 0)
    running = Workflow.create!(name: "Still going").runs.create!(status: "started")
    running.step_runs.create!(result: photo, status: "running")
    Workflow.create!(name: "Just a draft").runs.create!(status: "draft").step_runs.create!(result: photo, status: "complete")
    other = users(:admin_user).library_media.create!(kind: "photo", folder: folders(:business_card))
    Workflow.create!(name: "Other shop").runs.create!(status: "started").step_runs.create!(result: other, status: "complete")

    incoming = IncomingMessage.create!(channel: "whatsapp", user: @user, sender: "15551234567", kind: "text",
      body: "from the shop", payload: { "id" => "wamid.transcript-in" })
    outgoing = OutgoingMessage.create!(channel: "whatsapp", user: @user, recipient: "15551234567", kind: "text",
      body: "from rocketbox", payload: { "type" => "text" })
    incoming.update_columns(created_at: 3.minutes.ago)
    run.update_columns(created_at: 2.minutes.ago)
    outgoing.update_columns(created_at: 1.minute.ago)

    get whatsapp_url

    assert_response :success
    assert_no_match "card_filing", response.body
    assert_no_match "still_going", response.body

    sign_in_as(users(:admin_user))
    get whatsapp_url(account: @user.id)

    assert_response :success
    assert_match "card_filing", response.body
    assert_match "Complete", response.body
    assert_match "media_ids #{photo.id}", response.body
    assert_match "in media_id #{photo.id} · Inbox / Business card", response.body
    assert_match "out media_id #{photo.id} · Inbox / Business card", response.body
    assert_match "still_going", response.body
    assert_match "Running", response.body
    assert_no_match "just_a_draft", response.body
    assert_no_match "other_shop", response.body
    assert_select "a[href^=?]", workflow_path(workflow, run: run.id)
    assert_select "a[href^=?]", admin_workflow_run_path(run), text: "Admin"
    body = response.body
    assert_operator body.index("from the shop"), :<, body.index("card_filing")
    assert_operator body.index("card_filing"), :<, body.index("from rocketbox")
  end

  test "text from the composer is an incoming message and gets the agent reply" do
    original_request = WhatsappCloud.method(:request!)
    original_reply = RocketboxAgent.method(:reply)
    WhatsappCloud.define_singleton_method(:request!) { |*| { "messages" => [ { "id" => "wamid.dash-reply" } ] } }
    RocketboxAgent.define_singleton_method(:reply) { |*| Struct.new(:content).new("What's the business called?") }

    streams = nil
    assert_difference -> { IncomingMessage.where(channel: "whatsapp", kind: "text").count }, 1 do
      assert_no_difference -> { OutgoingMessage.count } do
        streams = capture_turbo_stream_broadcasts([ @user, :whatsapp, "owner" ]) do
          post whatsapp_url, params: { body: "hello from the desk" }
        end
      end
    end

    assert_response :no_content
    incoming = IncomingMessage.find_by!(channel: "whatsapp", body: "hello from the desk")
    assert_equal @user, incoming.user
    assert_equal "15551234567", incoming.sender
    assert_equal "replace", streams.sole["action"]
    assert_equal "whatsapp_messages", streams.sole["target"]
    assert_includes streams.sole.to_html, "hello from the desk"
    assert_not_includes streams.sole.to_html, "What's the business called?"

    reply_streams = capture_turbo_stream_broadcasts([ @user, :whatsapp, "owner" ]) do
      perform_enqueued_jobs(only: ReplyWhatsappMessageJob)
    end

    assert_includes reply_streams.sole.to_html, "What's the business called?"
    assert OutgoingMessage.exists?(channel: "whatsapp", body: "What's the business called?")
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
      assert_no_turbo_stream_broadcasts([ @user, :whatsapp, "owner" ]) do
        post whatsapp_url, params: { body: "  " }
      end
    end

    assert_response :no_content
  end
end
