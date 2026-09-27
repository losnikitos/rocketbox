# frozen_string_literal: true

require "test_helper"

class SignupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "show redirects to name step" do
    get sign_up_url
    assert_redirected_to sign_up_name_url
  end

  test "full signup with whatsapp skip" do
    post sign_up_name_url, params: { name: "Ada" }
    assert_redirected_to sign_up_business_url

    post sign_up_business_url, params: { business_name: "Ada Cuts" }
    assert_redirected_to sign_up_email_url

    assert_emails 1 do
      post sign_up_email_url, params: { email: "ada@example.com" }
    end
    assert_redirected_to sign_up_email_code_url

    Rails.cache.delete("login_otp_throttle:ada@example.com")
    challenge = LoginChallenge.issue!("ada@example.com")
    assert_difference -> { User.count }, 1 do
      post sign_up_email_code_url, params: { otp: challenge[:code] }
    end
    assert_redirected_to sign_up_whatsapp_url

    user = User.find_by!(email: "ada@example.com")
    assert_equal "Ada", user.name
    assert_equal "Ada Cuts", user.business_name
    assert user.verified?

    post sign_up_whatsapp_skip_url
    assert_redirected_to app_url
  end

  test "whatsapp step shows connect link until the phone is linked" do
    post sign_up_name_url, params: { name: "Bob" }
    post sign_up_business_url, params: { business_name: "Bob Barbers" }
    post sign_up_email_url, params: { email: "bob@example.com" }

    Rails.cache.delete("login_otp_throttle:bob@example.com")
    challenge = LoginChallenge.issue!("bob@example.com")
    post sign_up_email_code_url, params: { otp: challenge[:code] }

    original = WhatsappCloud.method(:display_phone)
    WhatsappCloud.define_singleton_method(:display_phone) { "447451273884" }

    get sign_up_whatsapp_url
    user = User.find_by!(email: "bob@example.com")
    assert_select "a[href=?]", "https://wa.me/447451273884?text=START_#{user.whatsapp_connect_code}", text: /Open WhatsApp/

    user.update!(whatsapp_phone: "15550109999")
    get sign_up_whatsapp_url
    assert_redirected_to app_url
  ensure
    WhatsappCloud.define_singleton_method(:display_phone, original)
  end

  test "existing email otp signs in and skips profile fields" do
    email = users(:lazaro_nixon).email

    post sign_up_name_url, params: { name: "Ada" }
    post sign_up_business_url, params: { business_name: "Ada Cuts" }

    assert_emails 1 do
      post sign_up_email_url, params: { email: email }
    end
    assert_redirected_to sign_up_email_code_url

    Rails.cache.delete("login_otp_throttle:#{email}")
    challenge = LoginChallenge.issue!(email)

    assert_no_difference -> { User.count } do
      post sign_up_email_code_url, params: { otp: challenge[:code] }
    end
    assert_redirected_to app_url

    user = users(:lazaro_nixon).reload
    assert_nil user.name
    assert_nil user.business_name
  end

  test "each step shows back link" do
    get sign_up_name_url
    assert_select "a", text: "← Back"

    post sign_up_name_url, params: { name: "Ada" }
    follow_redirect!
    assert_select "a[href=?]", sign_up_name_path, text: "← Back"
  end
end
