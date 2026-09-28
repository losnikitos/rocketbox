# frozen_string_literal: true

require "test_helper"

class Accounts::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "autosave update returns ok without redirect" do
    patch profile_settings_url,
      params: { user: { whatsapp_phone: "15551234567" } },
      headers: { "X-Autosave" => "1", "Accept" => "application/json" }

    assert_response :ok
    assert_equal "15551234567", @user.reload.whatsapp_phone
  end

  test "changing email unverifies and sends verification" do
    assert_enqueued_email_with UserMailer, :email_verification, params: { user: @user } do
      patch profile_settings_url,
        params: { user: { email: "New@Example.com" } },
        headers: { "X-Autosave" => "1", "Accept" => "application/json" }
    end

    assert_response :ok
    @user.reload
    assert_equal "new@example.com", @user.email
    assert_not @user.verified?
  end

  test "backfills orphan library media when whatsapp_phone is saved" do
    orphan = LibraryMedia.create!(
      whatsapp_media_id: "wa-media-1",
      whatsapp_from: "15551234567",
      kind: "photo"
    )

    patch profile_settings_url, params: { user: { whatsapp_phone: "+1 (555) 123-4567" } }

    assert_redirected_to profile_settings_url
    @user.reload
    assert_equal "15551234567", @user.whatsapp_phone
    assert_equal @user.id, orphan.reload.user_id
  end
end
