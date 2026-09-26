class UserMailer < ApplicationMailer
  include PostmarkRails::TemplatedMailerMixin

  def email_verification
    @user = params[:user]
    @signed_id = @user.generate_token_for(:email_verification)

    self.template_model = {
      user_email: @user.email,
      verification_url: identity_email_verification_url(sid: @signed_id)
    }

    mail to: @user.email, postmark_template_alias: "email_verification"
  end

  def login_otp
    email = params[:email]

    self.template_model = {
      user_email: email,
      otp_code: params[:otp_code],
      magic_login_url: sign_in_magic_url(sid: params[:magic_token])
    }

    mail to: email, postmark_template_alias: "login_otp"
  end
end
