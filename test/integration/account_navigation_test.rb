# frozen_string_literal: true

require "test_helper"

class AccountNavigationTest < ActionDispatch::IntegrationTest
  test "logged out header shows sign in and get started" do
    get root_url

    assert_response :success
    assert_select "a[href=?]", sign_in_path, minimum: 1
    assert_select "a[href=?]", sign_up_path, text: /Get started for free/
  end

  test "logged in landing header links to dashboard" do
    user = sign_in_as(users(:lazaro_nixon))

    get root_url

    assert_response :success
    assert_select "a[href=?]", app_path, text: "Go to Dashboard"
    assert_select "form[action=?]", session_path(user.sessions.last), count: 0
  end

  test "app library has primary Library nav and links to profile" do
    sign_in_as(users(:lazaro_nixon))

    get library_uploads_url

    assert_response :success
    assert_select "h1", "Library"
    assert_select "a[aria-label='Rocketbox home'][href=?]", root_path
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", library_uploads_path, text: /Library/
    assert_select "nav[aria-label='Secondary'] a[href=?][aria-selected='true']", library_uploads_path, text: /\AAll/
    assert_select "nav[aria-label='Primary'] a[href=?]", business_path, text: "Business"
    assert_select "nav[aria-label='Primary'] a[href=?]", profile_settings_path, text: "Profile"
    assert_select "nav[aria-label='Primary'] a[href=?]", instagram_posts_path, text: "Posts"
    assert_select "a[href=?]", onboarding_path, text: "Onboarding", count: 0
    assert_select "a[href='/jobs']", count: 0
    assert_select "a[href='/admin']", count: 0
    assert_select "[data-controller='env-switcher']", count: 0
  end

  test "business page shows primary Business nav" do
    sign_in_as(users(:lazaro_nixon))

    get business_url

    assert_response :success
    assert_select "h1", "Business"
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", business_path, text: /Business/
    assert_select "nav[aria-label='Primary'] a[href=?]", profile_settings_path, text: "Profile"
  end

  test "onboarding shows the exact WhatsApp messages per step" do
    admin = users(:admin_user)
    admin.update!(whatsapp_pending_question: "interior_front")
    sign_in_as(admin)

    get onboarding_url
    assert_response :success
    assert_select "li[aria-current='step']", count: 1, text: /Interior photos/
    assert_select "[popover] p", text: /Instagram’s connected/
    assert_select "[popover] p", text: /stand by the windows/

    get onboarding_url(tab: "media")
    assert_response :success
    assert_select "[popover] p", text: /stand by the windows/
  end

  test "admin sees onboarding link in primary nav" do
    sign_in_as(users(:admin_user))

    get library_uploads_url

    assert_response :success
    assert_select "nav[aria-label='Primary'] a[href=?]", profile_settings_path, text: "Profile"
    assert_select "nav[aria-label='Primary'] a[href=?]", onboarding_path, text: "Onboarding"
    assert_select "nav[aria-label='Primary'] a[href='/jobs']", text: /Jobs/
    assert_select "nav[aria-label='Primary'] a[href='/admin']", text: /Active Admin/
    assert_select "select#account_user_id"
    assert_select "[data-controller='env-switcher'][hidden] [data-origin='https://rocketbox.plus']", text: "Production"
  end

  test "profile page has no tabs and sidebar log out" do
    user = sign_in_as(users(:lazaro_nixon))

    get profile_settings_url

    assert_response :success
    assert_select "h1", "Profile"
    assert_select "form[action=?] input[name='user[whatsapp_phone]']", profile_settings_path
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", profile_settings_path, text: /Profile/
    assert_select "nav[aria-label='Secondary']", count: 0
    assert_select "aside form[action=?]", session_path(user.sessions.last) do
      assert_select "button", "Log out"
    end
  end

  test "instagram page is selected in nav with sidebar log out" do
    user = sign_in_as(users(:lazaro_nixon))

    get instagram_profile_url

    assert_response :success
    assert_select "h1", "Instagram"
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", instagram_profile_path, text: "Profile"
    assert_select "aside form[action=?]", session_path(user.sessions.last) do
      assert_select "button", "Log out"
    end
  end

  test "subscription page shows billing controls and sidebar log out" do
    user = sign_in_as(users(:lazaro_nixon))

    get subscription_url

    assert_response :success
    assert_select "h1", "Subscription"
    assert_select "nav[aria-label='Primary'] a[href=?][aria-selected='true']", subscription_path, text: /Subscription/
    assert_select "aside form[action=?]", session_path(user.sessions.last) do
      assert_select "button", "Log out"
    end
  end

  test "non-admin cannot see admin subscription controls" do
    sign_in_as(users(:lazaro_nixon))

    get subscription_url

    assert_response :success
    assert_select "h3", text: "Admin controls", count: 0
    assert_select "form[action=?]", subscription_status_path, count: 0
  end

  test "admin can adjust their own subscription status" do
    admin = sign_in_as(users(:admin_user))

    get subscription_url

    assert_response :success
    assert_select "h3", "Admin controls"
    assert_select "form[action=?]", subscription_status_path

    patch subscription_status_path, params: { subscription_status: "trialing" }
    assert_redirected_to subscription_path

    admin.subscription.reload
    assert_equal "trialing", admin.subscription.status
    assert admin.subscription.active?
  end

  test "non-admin cannot update subscription status" do
    user = sign_in_as(users(:lazaro_nixon))

    patch subscription_status_path, params: { subscription_status: "active" }
    assert_redirected_to subscription_path

    user.subscription.reload
    assert_not user.subscription.active?
    assert_nil user.subscription.status
  end
end
