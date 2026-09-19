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

  test "account page shows library with settings link" do
    sign_in_as(users(:lazaro_nixon))

    get account_url

    assert_response :success
    assert_select "h1", "Library"
    assert_select "nav[aria-label='Account sections']"
    assert_select "a[href=?][aria-current='page']", account_path, text: "Library"
    assert_select "a[href=?]", account_settings_path, text: "Settings"
  end

  test "settings page shows log out action" do
    user = sign_in_as(users(:lazaro_nixon))

    get account_settings_url

    assert_response :success
    assert_select "h1", "Settings"
    assert_select "nav[aria-label='Account sections']"
    assert_select "h2", text: "Integrations", count: 0
    assert_select "form[action=?]", session_path(user.sessions.last) do
      assert_select "button", "Log out"
    end
  end

  test "integrations page shows credentials form without log out" do
    user = sign_in_as(users(:lazaro_nixon))

    get account_integrations_url

    assert_response :success
    assert_select "h1", "Integrations"
    assert_select "form[action=?]", account_integrations_path
    assert_select "form[action=?]", session_path(user.sessions.last), count: 0
  end

  test "subscription page shows billing controls without log out" do
    user = sign_in_as(users(:lazaro_nixon))

    get account_subscription_url

    assert_response :success
    assert_select "h1", "Subscription"
    assert_select "form[action=?]", session_path(user.sessions.last), count: 0
  end

  test "non-admin cannot see admin subscription controls" do
    sign_in_as(users(:lazaro_nixon))

    get account_subscription_url

    assert_response :success
    assert_select "h2", text: "Admin controls", count: 0
    assert_select "form[action=?]", subscription_status_account_path, count: 0
  end

  test "admin can adjust their own subscription status" do
    admin = sign_in_as(users(:admin_user))

    get account_subscription_url

    assert_response :success
    assert_select "h2", "Admin controls"
    assert_select "form[action=?]", subscription_status_account_path

    patch subscription_status_account_path, params: { subscription_status: "trialing" }
    assert_redirected_to account_subscription_path

    admin.subscription.reload
    assert_equal "trialing", admin.subscription.status
    assert admin.subscription.active?
  end

  test "non-admin cannot update subscription status" do
    user = sign_in_as(users(:lazaro_nixon))

    patch subscription_status_account_path, params: { subscription_status: "active" }
    assert_redirected_to account_subscription_path

    user.subscription.reload
    assert_not user.subscription.active?
    assert_nil user.subscription.status
  end
end
