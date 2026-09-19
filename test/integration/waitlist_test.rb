# frozen_string_literal: true

require "test_helper"

class WaitlistTest < ActionDispatch::IntegrationTest
  test "guest can open the waitlist form" do
    get try_path

    assert_response :success
    assert_select "h1", text: /closed beta/i
    assert_select "form[action='#{try_path}']"
  end

  test "guest can join the waitlist" do
    assert_difference -> { WaitlistEntry.count }, 1 do
      post try_path, params: {
        waitlist_entry: {
          business_link: "https://instagram.com/example",
          email: "owner@example.com",
          phone: "+15551234567"
        }
      }
    end

    assert_redirected_to try_thanks_path
    follow_redirect!
    assert_response :success
    assert_select "h1", text: /Thanks/
    assert_match(/shortly/, response.body)

    entry = WaitlistEntry.last
    assert_equal "https://instagram.com/example", entry.business_link
    assert_equal "owner@example.com", entry.email
    assert_equal "+15551234567", entry.phone
  end

  test "invalid submission re-renders the form" do
    assert_no_difference -> { WaitlistEntry.count } do
      post try_path, params: {
        waitlist_entry: {
          business_link: "",
          email: "not-an-email",
          phone: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "form[action='#{try_path}']"
  end
end
