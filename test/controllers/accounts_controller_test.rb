# frozen_string_literal: true

require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "should update integrations" do
    patch account_url, params: {
      user: {
        instagram_user_id: "28810616161875865",
        instagram_access_token: "ig-token-example",
        telegram_user_id: 90504516
      }
    }

    assert_redirected_to account_url
    assert_equal "Account updated.", flash[:notice]

    @user.reload
    assert_equal "28810616161875865", @user.instagram_user_id
    assert_equal "ig-token-example", @user.instagram_access_token
    assert_equal 90504516, @user.telegram_user_id
  end
end
