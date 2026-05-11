# frozen_string_literal: true

class UserMailerPreview < ActionMailer::Preview
  def password_reset
    UserMailer.with(user: User.first).password_reset
  end

  def email_verification
    UserMailer.with(user: User.first).email_verification
  end
end
