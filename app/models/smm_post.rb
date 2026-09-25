# frozen_string_literal: true

class SmmPost < ApplicationRecord
  STATUSES = %w[draft generating ready published failed].freeze
  MAX_MEDIA = 7

  belongs_to :user
  belongs_to :prompt
  has_many :smm_post_media_items, -> { order(:position) }, dependent: :destroy, inverse_of: :smm_post
  has_many :library_media, through: :smm_post_media_items
  has_one_attached :generated_video

  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :media_count_within_limits
  validate :media_must_be_images

  scope :recent, -> { order(created_at: :desc) }

  def draft?
    status == "draft"
  end

  def generating?
    status == "generating"
  end

  def ready?
    status == "ready"
  end

  def published?
    status == "published"
  end

  def failed?
    status == "failed"
  end

  def publishable?
    ready? && generated_video.attached?
  end

  def mark_generating!
    update!(status: "generating", error_message: nil)
  end

  def mark_ready!
    update!(status: "ready", error_message: nil)
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message.to_s.truncate(1000))
  end

  def mark_published!
    update!(status: "published", published_at: Time.current, error_message: nil)
  end

  private

    def media_count_within_limits
      count = smm_post_media_items.size
      if count < 1
        errors.add(:base, "Select at least one image from your library.")
      elsif count > MAX_MEDIA
        errors.add(:base, "Select at most #{MAX_MEDIA} images.")
      end
    end

    def media_must_be_images
      smm_post_media_items.each do |item|
        media = item.library_media
        next if media.blank?
        next if media.story_image?

        errors.add(:base, "Only images can be used to generate a post video.")
        break
      end
    end
end
