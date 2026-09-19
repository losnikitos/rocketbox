# frozen_string_literal: true

require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as(users(:lazaro_nixon))
  end

  test "should show account" do
    get account_url
    assert_response :success
    assert_select "h1", "Account"
  end
end
