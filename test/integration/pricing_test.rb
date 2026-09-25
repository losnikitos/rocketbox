# frozen_string_literal: true

require "test_helper"

class PricingTest < ActionDispatch::IntegrationTest
  test "pricing page is public and shows tiers with waitlist CTAs" do
    get pricing_path

    assert_response :success
    assert_select "h1", text: "Pricing"
    assert_select "h3", text: "Starter"
    assert_select "h3", text: "Pro"
    assert_select "h3", text: "Growth"
    assert_select "p", text: /£29/
    assert_select "p", text: /£59/
    assert_select "p", text: /£119/
    assert_select "span", text: "+VAT", count: 3
    assert_select "a[href='#{try_path}']", text: "Join the waitlist"
    assert_select "a[href='#{new_subscribe_path}']", count: 0
    assert_select "form[action='#{profile_checkout_path}']", count: 0
  end

  test "pricing is linked from header and footer" do
    get pricing_path

    assert_response :success
    assert_select "nav[aria-label='Primary'] a[href='#{pricing_path}']", text: "Pricing"
    assert_select "nav[aria-label='Product'] a[href='#{pricing_path}']", text: "Pricing"
  end
end
