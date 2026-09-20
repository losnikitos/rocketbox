# frozen_string_literal: true

require "test_helper"

class UseCasesTest < ActionDispatch::IntegrationTest
  test "guest can view a known use case" do
    get use_case_path("barbershops")

    assert_response :success
    assert_select "h1", text: /fade/
    assert_select "a[href='#{try_path}']", text: "Join the waitlist"
    assert_select "a[href='#{new_subscription_path}']", count: 0
    assert_select "[aria-label='Fade House Google Maps listing']"
  end

  test "unknown use case returns not found" do
    get use_case_path("not-a-real-vertical")

    assert_response :not_found
  end

  test "primary nav lists use case links for guests" do
    get root_path

    assert_response :success
    assert_select "button[popovertarget='use-cases-menu']", text: "Use cases"
    UseCasesController::REGISTRY.each_key do |slug|
      assert_select "a[href='#{use_case_path(slug)}']"
    end
  end
end
