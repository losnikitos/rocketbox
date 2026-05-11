require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:lazaro_nixon)
  end

  test "password_reset" do
    mail = UserMailer.with(user: @user).password_reset
    assert_equal [ @user.email ], mail.to
    assert_equal "password_reset", mail.template_alias

    model = mail.template_model
    assert_equal @user.email, model[:user_email]
    assert_kind_of String, model[:reset_password_url]
    assert_match %r{/identity/password_reset/edit}, model[:reset_password_url]
    assert_match(/sid=/, model[:reset_password_url])
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
end
