require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "should get index" do
    sign_in_as @user

    get sessions_url
    assert_response :success
  end

  test "should get new" do
    get sign_in_url
    assert_response :success
  end

  test "should request otp email" do
    assert_emails 1 do
      post sign_in_url, params: { email: @user.email }
    end
    assert_redirected_to sign_in_otp_url(email: @user.email)
  end

  test "should sign in with otp and create user for new email" do
    email = "otp-new@example.com"
    challenge = LoginChallenge.issue!(email)

    assert_difference -> { User.count }, 1 do
      post sign_in_otp_url, params: { email: email, otp: challenge[:code] }
    end
    assert_redirected_to app_url

    user = User.find_by!(email: email)
    assert user.verified?
  end

  test "should sign in existing user with otp" do
    challenge = LoginChallenge.issue!(@user.email)

    assert_no_difference -> { User.count } do
      post sign_in_otp_url, params: { email: @user.email, otp: challenge[:code] }
    end
    assert_redirected_to app_url
  end

  test "should not sign in with bad otp" do
    LoginChallenge.issue!(@user.email)

    post sign_in_otp_url, params: { email: @user.email, otp: "000000" }
    assert_response :unprocessable_entity
  end

  test "should sign in with magic link" do
    email = "magic-new@example.com"
    challenge = LoginChallenge.issue!(email)

    assert_difference -> { User.count }, 1 do
      get sign_in_magic_url(sid: challenge[:token])
    end
    assert_redirected_to app_url
  end

  test "sign in uses auth layout without marketing header" do
    get sign_in_url(email_hint: @user.email)
    assert_response :success
    assert_select "nav[aria-label='Primary']", count: 0
    assert_select "a", text: "← Back"
    assert_select "h1", "Your email"
  end

  test "should reject invalid magic link" do
    get sign_in_magic_url(sid: "not-a-valid-token")
    assert_redirected_to sign_in_url
    assert_equal "That login link is invalid or expired", flash[:alert]
  end

  test "should sign out" do
    sign_in_as @user

    delete session_url(@user.sessions.last)
    assert_redirected_to sessions_url

    follow_redirect!
    assert_redirected_to sign_in_url
  end
end
