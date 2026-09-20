# frozen_string_literal: true

require "test_helper"

class HomeCtaTest < ActionDispatch::IntegrationTest
  test "home shows waitlist CTA and closed beta messaging" do
    get root_path

    assert_response :success
    assert_select "h1", text: /handle marketing/i
    assert_select "a[href='#{try_path}']", text: "Join the waitlist"
    assert_select "a[href='#{new_subscription_path}']", count: 0
    assert_select "form[action='#{checkout_account_path}']", count: 0
  end

  test "home shows barbershop proof demos" do
    get root_path

    assert_response :success
    assert_select "section[aria-labelledby='proof-heading']"
    assert_select "img[src='/use-cases/barbershops/alan.jpg']"
    assert_select "img[src='/use-cases/barbershops/bob.jpg']"
    assert_select "video[src='/use-cases/barbershops/alan.mp4']"
    assert_select "video[src='/use-cases/barbershops/bob.mp4']"
    assert_select "[aria-label='Fade House Google Maps listing']"
    assert_select "[aria-label='Fade House Instagram profile']"
  end
end
