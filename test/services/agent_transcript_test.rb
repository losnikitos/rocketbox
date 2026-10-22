# frozen_string_literal: true

require "test_helper"

class AgentTranscriptTest < ActiveSupport::TestCase
  test "renders a photo, the workflow that filed it, and the reply that followed" do
    user = users(:lazaro_nixon)
    chat = user.create_chat!
    photo = user.library_media.create!(kind: "photo", folder: folders(:business_card))
    incoming = IncomingMessage.create!(channel: "whatsapp", user:, kind: "image", body: nil, payload: { "id" => "wamid.photo" })
    incoming.attachments.attach(io: StringIO.new("img"), filename: "card.jpg", content_type: "image/jpeg")

    workflow = Workflow.create!(name: "Inbox sort")
    run = workflow.runs.create!(status: "started", picks: { "9" => [ photo.id ] })
    step = run.step_runs.create!(result: photo, status: "complete")
    step.inputs.create!(item: photo, position: 0)

    OutgoingMessage.create!(channel: "whatsapp", user:, recipient: "1", kind: "text", body: "Send me your card", payload: { "type" => "text" })
    OutgoingMessage.create!(channel: "whatsapp", user:, recipient: "1", kind: "reaction", body: "👍", payload: { "type" => "reaction" })
    Workflow.create!(name: "Still going").runs.create!(status: "started").step_runs.create!(result: photo, status: "running")

    incoming.update_columns(created_at: 3.minutes.ago)
    run.update_columns(created_at: 2.minutes.ago)
    user.outgoing_messages.update_all(created_at: 1.minute.ago)

    AgentTranscript.call(chat, user)

    messages = chat.messages.order(:created_at, :id).to_a
    assert_equal %w[user assistant tool assistant], messages.map(&:role)
    assert_equal "Sent a photo", messages[0].content
    assert_not messages[0].attachments.attached?

    call = messages[1].tool_calls.values.sole
    assert_equal "inbox_sort", call.name
    assert_equal [ photo.id ], call.arguments[:media_ids] || call.arguments["media_ids"]
    assert_equal "run_#{run.id}", messages[2].parent_tool_call.id

    result = JSON.parse(messages[2].content)
    assert_equal "complete", result["status"]
    assert_equal photo.id, result["outputs"].sole["media_id"]
    assert_equal "Inbox / Business card", result["outputs"].sole["folder"]
    assert_equal "Send me your card", messages[3].content

    chat.messages.destroy_all
    AgentTranscript.call(chat, user)
    assert_equal %w[user assistant tool assistant], chat.messages.order(:created_at, :id).pluck(:role)
  end

  test "a captioned photo is a text note and the file stays off the chat" do
    user = users(:lazaro_nixon)
    chat = user.create_chat!
    incoming = IncomingMessage.create!(channel: "whatsapp", user:, kind: "image", body: "front of the shop", payload: { "id" => "wamid.caption" })
    incoming.attachments.attach(io: StringIO.new("img"), filename: "shop.jpg", content_type: "image/jpeg")

    AgentTranscript.call(chat, user)

    message = chat.messages.sole
    assert_equal "Sent a photo: front of the shop", message.content
    assert_not message.attachments.attached?
  end
end
