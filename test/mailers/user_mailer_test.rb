require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "email_verification" do
    mail = UserMailer.with(user: @user).email_verification
    assert_equal [ @user.email ], mail.to
    assert_equal "email_verification", mail.template_alias

    model = mail.template_model
    assert_equal @user.email, model[:user_email]
    assert_kind_of String, model[:verification_url]
    assert_match %r{/identity/email_verification}, model[:verification_url]
    assert_match(/sid=/, model[:verification_url])
  end

  test "login_otp" do
    mail = UserMailer.with(
      email: @user.email,
      otp_code: "123456",
      magic_token: "tok"
    ).login_otp
    assert_equal [ @user.email ], mail.to
    assert_equal "login_otp", mail.template_alias

    model = mail.template_model
    assert_equal @user.email, model[:user_email]
    assert_equal "123456", model[:otp_code]
  end
end
