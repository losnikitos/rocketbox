# frozen_string_literal: true

require "test_helper"

class Accounts::IntegrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "should show integrations" do
    get profile_integrations_url
    assert_response :success
    assert_select "h1", "Profile"
    assert_select "h2", "Integrations"
  end

  test "should update integrations" do
    patch profile_integrations_url, params: {
      user: {
        instagram_user_id: "28810616161875865",
        instagram_access_token: "ig-token-example",
        telegram_user_id: 90504516
      }
    }

    assert_redirected_to profile_integrations_url
    assert_equal "Account updated.", flash[:notice]

    @user.reload
    assert_equal "28810616161875865", @user.instagram_user_id
    assert_equal "ig-token-example", @user.instagram_access_token
    assert_equal 90504516, @user.telegram_user_id
  end

  test "backfills orphan library media when telegram_user_id is saved" do
    orphan = LibraryMedia.create!(
      telegram_file_id: "file-1",
      telegram_file_unique_id: "unique-1",
      chat_id: 90504516,
      from_id: 90504516,
      kind: "photo"
    )

    patch profile_integrations_url, params: { user: { telegram_user_id: 90504516 } }

    assert_redirected_to profile_integrations_url
    assert_equal @user.id, orphan.reload.user_id
  end

  test "backfills orphan library media when whatsapp_phone is saved" do
    orphan = LibraryMedia.create!(
      whatsapp_media_id: "wa-media-1",
      whatsapp_from: "15551234567",
      kind: "photo"
    )

    patch profile_integrations_url, params: { user: { whatsapp_phone: "+1 (555) 123-4567" } }

    assert_redirected_to profile_integrations_url
    @user.reload
    assert_equal "15551234567", @user.whatsapp_phone
    assert_equal @user.id, orphan.reload.user_id
  end
end
