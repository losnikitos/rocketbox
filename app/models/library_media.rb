# frozen_string_literal: true

class LibraryMedia < ApplicationRecord
  belongs_to :user, optional: true
  has_one_attached :file

  validates :kind, presence: true
  validates :telegram_file_unique_id, uniqueness: true, allow_nil: true
  validates :whatsapp_media_id, uniqueness: true, allow_nil: true
  validate :channel_identity_present

  def story_image?
    return false unless file.attached?

    file.content_type.to_s.start_with?("image/") || kind.in?(%w[photo sticker])
  end

  def story_video?
    return false unless file.attached?

    file.content_type.to_s.start_with?("video/") || kind.in?(%w[video video_note animation])
  end

  def story_publishable?
    story_image? || story_video?
  end

  private

    def channel_identity_present
      telegram = telegram_file_id.present? && telegram_file_unique_id.present?
      whatsapp = whatsapp_media_id.present?
      return if telegram || whatsapp

      errors.add(:base, "Telegram or WhatsApp media identity is required")
    end
end
