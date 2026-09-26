# frozen_string_literal: true

class LoginChallenge
  SALT = "rocketbox/login/v1"
  EXPIRES_IN = 15.minutes
  RESEND_AFTER = 60.seconds
  MAX_ATTEMPTS = 5
  CODE_LENGTH = 6

  class << self
    def issue!(email)
      email = normalize(email)
      return :throttled if throttled?(email)

      code = SecureRandom.random_number(10**CODE_LENGTH).to_s.rjust(CODE_LENGTH, "0")
      Rails.cache.write(
        otp_key(email),
        { digest: BCrypt::Password.create(code).to_s, attempts: 0 },
        expires_in: EXPIRES_IN
      )
      Rails.cache.write(throttle_key(email), true, expires_in: RESEND_AFTER)

      token = Rails.application.message_verifier(SALT).generate(email, expires_in: EXPIRES_IN)
      { email:, code:, token: }
    end

    def issue_and_deliver!(email)
      challenge = issue!(email)
      return challenge if challenge == :throttled

      UserMailer.with(
        email: challenge[:email],
        otp_code: challenge[:code],
        magic_token: challenge[:token]
      ).login_otp.deliver_later

      challenge
    end

    def verify_code!(email, code)
      email = normalize(email)
      payload = Rails.cache.read(otp_key(email))
      return false unless payload.is_a?(Hash)

      attempts = payload[:attempts].to_i + 1
      if attempts > MAX_ATTEMPTS
        Rails.cache.delete(otp_key(email))
        return false
      end

      digest = payload[:digest]
      if digest.present? && BCrypt::Password.new(digest) == code.to_s
        consume!(email)
        true
      else
        Rails.cache.write(
          otp_key(email),
          payload.merge(attempts:),
          expires_in: EXPIRES_IN
        )
        false
      end
    rescue BCrypt::Errors::InvalidHash
      false
    end

    def verify_token!(token)
      email = Rails.application.message_verifier(SALT).verify(token)
      consume!(email)
      email
    end

    def normalize(email)
      email.to_s.strip.downcase
    end

    private

      def consume!(email)
        Rails.cache.delete(otp_key(email))
      end

      def throttled?(email)
        Rails.cache.exist?(throttle_key(email))
      end

      def otp_key(email)
        "login_otp:#{email}"
      end

      def throttle_key(email)
        "login_otp_throttle:#{email}"
      end
  end
end
