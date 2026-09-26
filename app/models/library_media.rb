# frozen_string_literal: true

class LibraryMedia < ApplicationRecord
  belongs_to :user, optional: true
  has_one_attached :file

  validates :kind, presence: true
  validates :telegram_file_unique_id, uniqueness: true, allow_nil: true
  validates :whatsapp_media_id, uniqueness: true, allow_nil: true

  def story_image?
    return false unless file.attached?

    file.content_type.to_s.start_with?("image/") || kind.in?(%w[photo sticker])
  end

  def self.kind_for(content_type)
    case content_type.to_s
    when /\Aimage\// then "photo"
    when /\Avideo\// then "video"
    when /\Aaudio\// then "audio"
    else "document"
    end
  end
end
