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

  test "full signup with phone skip" do
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
    assert_redirected_to sign_up_phone_url

    user = User.find_by!(email: "ada@example.com")
    assert_equal "Ada", user.name
    assert_equal "Ada Cuts", user.business_name
    assert user.verified?

    post sign_up_phone_skip_url
    assert_redirected_to app_url
  end

  test "signup with phone confirmation" do
    post sign_up_name_url, params: { name: "Bob" }
    post sign_up_business_url, params: { business_name: "Bob Barbers" }
    post sign_up_email_url, params: { email: "bob@example.com" }

    Rails.cache.delete("login_otp_throttle:bob@example.com")
    challenge = LoginChallenge.issue!("bob@example.com")
    post sign_up_email_code_url, params: { otp: challenge[:code] }

    post sign_up_phone_url, params: { phone: "+1 (555) 010-9999" }
    assert_redirected_to sign_up_phone_code_url
    assert_equal "15550109999", User.find_by!(email: "bob@example.com").whatsapp_phone

    post sign_up_phone_code_url, params: { otp: SignupsController::PHONE_STUB_CODE }
    assert_redirected_to app_url
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
