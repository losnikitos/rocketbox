# frozen_string_literal: true

class Review < ApplicationRecord
  belongs_to :user
  has_one_attached :avatar
  has_many_attached :media

  enum :source, %w[google fresha trustpilot].index_by(&:itself), validate: true

  validates :customer_name, presence: true
  validates :rating, inclusion: { in: 1..5 }
  validate :media_are_images_or_videos

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :with_media, -> { where(id: ActiveStorage::Attachment.where(record_type: name, name: "media").select(:record_id)) }

  def archived? = archived_at.present?

  private

    def media_are_images_or_videos
      errors.add(:media, "must be images or videos") unless media.all? { |m| m.content_type.to_s.start_with?("image/", "video/") }
    end
end
