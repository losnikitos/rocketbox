# frozen_string_literal: true

class DemoPreviewLink
  SALT = "rocketbox/demo_chapter_preview/v1"
  EXPIRATION_DAYS = 7
  EXPIRES_IN = EXPIRATION_DAYS.days

  class << self
    def generate!(email)
      Rails.application.message_verifier(SALT).generate(
        email.to_s.strip.downcase,
        expires_in: EXPIRES_IN
      )
    end

    def read(token)
      Rails.application.message_verifier(SALT).verified(token)
    end
  end
end
