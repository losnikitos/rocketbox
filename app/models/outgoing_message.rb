# frozen_string_literal: true

class OutgoingMessage < ApplicationRecord
  belongs_to :user, optional: true

  validates :channel, presence: true
  validates :payload, presence: true

  after_create_commit -> { user.broadcast_whatsapp_thread }, if: -> { channel == "whatsapp" && user }

  # Auditing must never break a send.
  def self.log(**attrs)
    create!(attrs)
  rescue => e
    Rails.logger.error("OutgoingMessage.log failed: #{e.class}: #{e.message}")
    nil
  end
end
