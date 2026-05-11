# frozen_string_literal: true

require "test_helper"

class HomeCtaTest < ActionDispatch::IntegrationTest
  test "guest users see subscribe link to subscription form" do
    get root_path

    assert_response :success
    assert_select "a[href='#{new_free_preview_path}']", text: "Start with a free preview"
    assert_select "a[href='#{new_subscription_path}']", text: "Subscribe"
    assert_select "form[action='#{checkout_account_path}']", count: 0
  end

  test "signed in non-subscribed users see preview and checkout buttons" do
    sign_in_as(users(:lazaro_nixon))
    get root_path

    assert_response :success
    assert_select "a[href='#{books_path}']", text: "Preview"
    assert_select "form[action='#{checkout_account_path}'][method='post']"
    assert_select "button", text: "Subscribe with Stripe Checkout"
    assert_select "a[href='#{new_free_preview_path}']", count: 0
    assert_select "a[href='#{new_subscription_path}']", count: 0
  end

  test "signed in subscribed users see read the books only" do
    user = users(:lazaro_nixon)
    user.subscription.update!(active: true)

    sign_in_as(user)
    get root_path

    assert_response :success
    assert_select "a[href='#{books_path}']", text: "Read the books"
    assert_select "form[action='#{checkout_account_path}']", count: 0
    assert_select "a[href='#{new_subscription_path}']", count: 0
    assert_select "a[href='#{new_free_preview_path}']", count: 0
  end
end
