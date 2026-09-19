# frozen_string_literal: true

require "test_helper"

class HomeCtaTest < ActionDispatch::IntegrationTest
  test "guest users see subscribe link to subscription form" do
    get root_path

    assert_response :success
    assert_select "a[href='#{new_subscription_path}']", text: "Subscribe"
    assert_select "form[action='#{checkout_account_path}']", count: 0
  end

  test "signed in non-subscribed users see checkout button" do
    sign_in_as(users(:lazaro_nixon))
    get root_path

    assert_response :success
    assert_select "form[action='#{checkout_account_path}'][method='post']"
    assert_select "button", text: "Subscribe with Stripe Checkout"
    assert_select "a[href='#{new_subscription_path}']", count: 0
  end

  test "signed in subscribed users see open library only" do
    user = users(:lazaro_nixon)
    user.subscription.update!(active: true)

    sign_in_as(user)
    get root_path

    assert_response :success
    assert_select "a[href='#{library_path}']", text: "Open library"
    assert_select "form[action='#{checkout_account_path}']", count: 0
    assert_select "a[href='#{new_subscription_path}']", count: 0
  end
end
