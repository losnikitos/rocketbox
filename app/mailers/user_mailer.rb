class UserMailer < ApplicationMailer
  include PostmarkRails::TemplatedMailerMixin

  def password_reset
    @user = params[:user]
    @signed_id = @user.generate_token_for(:password_reset)

    self.template_model = {
      user_email: @user.email,
      reset_password_url: edit_identity_password_reset_url(sid: @signed_id)
    }

    mail to: @user.email, postmark_template_alias: "password_reset"
  end

  def email_verification
    @user = params[:user]
    @signed_id = @user.generate_token_for(:email_verification)

    self.template_model = {
      user_email: @user.email,
      verification_url: identity_email_verification_url(sid: @signed_id)
    }

    mail to: @user.email, postmark_template_alias: "email_verification"
  end
end
