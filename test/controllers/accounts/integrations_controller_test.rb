# frozen_string_literal: true

require "test_helper"

class Accounts::IntegrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "should show integrations" do
    get account_integrations_url
    assert_response :success
    assert_select "h1", "Integrations"
  end

  test "should update integrations" do
    patch account_integrations_url, params: {
      user: {
        instagram_user_id: "28810616161875865",
        instagram_access_token: "ig-token-example",
        telegram_user_id: 90504516
      }
    }

    assert_redirected_to account_integrations_url
    assert_equal "Account updated.", flash[:notice]

    @user.reload
    assert_equal "28810616161875865", @user.instagram_user_id
    assert_equal "ig-token-example", @user.instagram_access_token
    assert_equal 90504516, @user.telegram_user_id
  end

  test "backfills orphan telegram uploads when telegram_user_id is saved" do
    orphan = TelegramUpload.create!(
      telegram_file_id: "file-1",
      telegram_file_unique_id: "unique-1",
      chat_id: 90504516,
      from_id: 90504516,
      kind: "photo"
    )

    patch account_integrations_url, params: { user: { telegram_user_id: 90504516 } }

    assert_redirected_to account_integrations_url
    assert_equal @user.id, orphan.reload.user_id
  end
end
