# frozen_string_literal: true

class UserMailerPreview < ActionMailer::Preview
  def email_verification
    UserMailer.with(user: User.first).email_verification
  end

  def login_otp
    UserMailer.with(
      email: User.first&.email || "preview@example.com",
      otp_code: "123456",
      magic_token: "preview-token"
    ).login_otp
  end
end
