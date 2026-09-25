# frozen_string_literal: true

require "test_helper"

class AccountNavigationTest < ActionDispatch::IntegrationTest
  test "logged out header shows sign in without sign up" do
    get root_url

    assert_response :success
    assert_select "a[href=?]", sign_in_path, minimum: 1
    assert_select "a[href=?]", sign_up_path, count: 0
  end

  test "logged in landing header links to dashboard" do
    user = sign_in_as(users(:lazaro_nixon))

    get root_url

    assert_response :success
    assert_select "a[href=?]", app_path, text: "Go to Dashboard"
    assert_select "form[action=?]", session_path(user.sessions.last), count: 0
  end

  test "app library has folder nav and links to profile" do
    sign_in_as(users(:lazaro_nixon))

    get library_url

    assert_response :success
    assert_select "h1", "Uploads"
    assert_select "nav[aria-label='Library folders']"
    assert_select "nav[aria-label='Profile sections']", count: 0
    assert_select "a[href=?]", profile_settings_path, text: "My profile"
    assert_select "a[href=?]", monitor_path, text: "Monitor", count: 0
  end

  test "admin sees monitor link next to my profile" do
    sign_in_as(users(:admin_user))

    get library_url

    assert_response :success
    assert_select "a[href=?]", profile_settings_path, text: "My profile"
    assert_select "a[href=?]", monitor_path, text: "Monitor"
  end

  test "settings page shows log out action" do
    user = sign_in_as(users(:lazaro_nixon))

    get profile_settings_url

    assert_response :success
    assert_select "h1", "Settings"
    assert_select "nav[aria-label='Profile sections']"
    assert_select "a[href=?][aria-current='page']", profile_settings_path, text: "Settings"
    assert_select "a[href=?]", profile_integrations_path, text: "Integrations"
    assert_select "a[href=?]", profile_subscription_path, text: "Subscription"
    assert_select "h2", text: "Integrations", count: 0
    assert_select "form[action=?]", session_path(user.sessions.last) do
      assert_select "button", "Log out"
    end
  end

  test "integrations page shows credentials form without log out" do
    user = sign_in_as(users(:lazaro_nixon))

    get profile_integrations_url

    assert_response :success
    assert_select "h1", "Integrations"
    assert_select "form[action=?]", profile_integrations_path
    assert_select "form[action=?]", session_path(user.sessions.last), count: 0
  end

  test "subscription page shows billing controls without log out" do
    user = sign_in_as(users(:lazaro_nixon))

    get profile_subscription_url

    assert_response :success
    assert_select "h1", "Subscription"
    assert_select "form[action=?]", session_path(user.sessions.last), count: 0
  end

  test "non-admin cannot see admin subscription controls" do
    sign_in_as(users(:lazaro_nixon))

    get profile_subscription_url

    assert_response :success
    assert_select "h2", text: "Admin controls", count: 0
    assert_select "form[action=?]", profile_subscription_status_path, count: 0
  end

  test "admin can adjust their own subscription status" do
    admin = sign_in_as(users(:admin_user))

    get profile_subscription_url

    assert_response :success
    assert_select "h2", "Admin controls"
    assert_select "form[action=?]", profile_subscription_status_path

    patch profile_subscription_status_path, params: { subscription_status: "trialing" }
    assert_redirected_to profile_subscription_path

    admin.subscription.reload
    assert_equal "trialing", admin.subscription.status
    assert admin.subscription.active?
  end

  test "non-admin cannot update subscription status" do
    user = sign_in_as(users(:lazaro_nixon))

    patch profile_subscription_status_path, params: { subscription_status: "active" }
    assert_redirected_to profile_subscription_path

    user.subscription.reload
    assert_not user.subscription.active?
    assert_nil user.subscription.status
  end
end
