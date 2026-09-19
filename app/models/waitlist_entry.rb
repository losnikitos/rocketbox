# frozen_string_literal: true

class WaitlistEntry < ApplicationRecord
  validates :business_link, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true

  before_validation :normalize_email

  private

    def normalize_email
      self.email = email.to_s.strip.downcase.presence
    end
end
