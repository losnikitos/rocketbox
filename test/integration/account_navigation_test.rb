# frozen_string_literal: true

require "test_helper"

class AccountNavigationTest < ActionDispatch::IntegrationTest
  test "logged out header shows sign in without sign up" do
    get root_url

    assert_response :success
    assert_select "a[href=?]", sign_in_path, minimum: 1
    assert_select "a[href=?]", sign_up_path, count: 0
  end

  test "logged in header links to account without log out" do
    user = sign_in_as(users(:lazaro_nixon))

    get root_url

    assert_response :success
    assert_select "a[href=?]", account_path, text: "My account"
    assert_select "form[action=?]", session_path(user.sessions.last), count: 0
  end

  test "account page shows log out action" do
    user = sign_in_as(users(:lazaro_nixon))

    get account_url

    assert_response :success
    assert_select "h1", "My account"
    assert_select "form[action=?]", session_path(user.sessions.last) do
      assert_select "button", "Log out"
    end
  end
end
