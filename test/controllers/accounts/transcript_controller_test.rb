# frozen_string_literal: true

require "test_helper"

class Accounts::TranscriptControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    @user.update!(whatsapp_phone: "15551234567")
    IncomingMessage.create!(channel: "whatsapp", user: @user, sender: "15551234567", external_id: "wamid.photo",
      kind: "image", body: "front of the shop", payload: { "id" => "wamid.photo", "type" => "image" })
      .attachments.attach(io: StringIO.new("img"), filename: "cut.jpg", content_type: "image/jpeg")
  end

  test "an owner cannot open the transcript" do
    sign_in_as(@user)

    get transcript_url

    assert_redirected_to root_url
  end

  test "an admin reads the transcript the model sees" do
    sign_in_as(users(:admin_user))

    assert_no_difference -> { Message.count } do
      get transcript_url(account: @user.id)
    end

    assert_response :success
    assert_select "section[aria-label='Agent transcript']"
    assert_select "section[aria-label='Agent transcript'] img", count: 0
    assert_match "You cannot see the image", response.body
    assert_match "Onboarding:", response.body
    assert_match "Sent a photo: front of the shop", response.body
    assert_select "[data-role=system] .bg-white"
    assert_select "[data-role=user] .text-rocket", text: "user"
    assert_select "[data-role=user] .bg-white", text: /Sent a photo/
    assert_select "a[href=?]", transcript_path(account: @user.id), text: "Transcript"
    assert_select "a[href=?]", admin_path(account: @user.id), text: "Dashboard"
    assert_select "nav[aria-label='Primary'] a[aria-selected=true]", text: "Transcript"
  end
end
