# frozen_string_literal: true

module AuthFlow
  extend ActiveSupport::Concern

  private

    def issue_email_otp!(email)
      challenge = LoginChallenge.issue_and_deliver!(email)
      return challenge if challenge == :throttled

      session[:otp_preview] = challenge[:code] if Rails.env.development?
      challenge
    end

    def otp_preview_code
      session[:otp_preview] if Rails.env.development?
    end

    def start_session!(user)
      session_record = user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }
      Current.session = session_record
    end

    def clear_otp_preview!
      session.delete(:otp_preview)
      session.delete(:signup_otp_code)
    end
end
