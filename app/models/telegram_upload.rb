# frozen_string_literal: true

class TelegramUpload < ApplicationRecord
  belongs_to :user, optional: true
  has_one_attached :file

  validates :telegram_file_id, :telegram_file_unique_id, :kind, presence: true
  validates :telegram_file_unique_id, uniqueness: true

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
end

