# frozen_string_literal: true

require "test_helper"

class LoginChallengeTest < ActiveSupport::TestCase
  setup do
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @email = "challenge@example.com"
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "issue returns code and token then verify_code consumes it" do
    challenge = LoginChallenge.issue!(@email)
    assert_match(/\A\d{6}\z/, challenge[:code])
    assert challenge[:token].present?

    assert LoginChallenge.verify_code!(@email, challenge[:code])
    assert_not LoginChallenge.verify_code!(@email, challenge[:code])
  end

  test "verify_token returns email and consumes otp" do
    challenge = LoginChallenge.issue!(@email)
    assert_equal @email, LoginChallenge.verify_token!(challenge[:token])
    assert_not LoginChallenge.verify_code!(@email, challenge[:code])
  end

  test "throttles resend within window" do
    assert LoginChallenge.issue!(@email).is_a?(Hash)
    assert_equal :throttled, LoginChallenge.issue!(@email)
  end

  test "rejects bad code" do
    LoginChallenge.issue!(@email)
    assert_not LoginChallenge.verify_code!(@email, "000000")
  end
end
