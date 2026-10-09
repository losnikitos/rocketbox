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
  # What a review step picks from.
  scope :postable, -> { active.where(rating: 5).where.not(body: [ nil, "" ]) }
  scope :with_media, -> { where(id: ActiveStorage::Attachment.where(record_type: name, name: "media").select(:record_id)) }

  def self.media_attachments = ActiveStorage::Attachment.where(record: all, name: "media")

  def archived? = archived_at.present?

  # The Review layer's fields.
  def layer_values
    photo = avatar.variant(resize_to_fill: [ 256, 256 ], format: :jpeg).processed if avatar.attached?
    { text: body.truncate(240, separator: " "), name: customer_name,
      photo: ("data:image/jpeg;base64,#{Base64.strict_encode64(photo.download)}" if photo) }
  end

  private

    def media_are_images_or_videos
      errors.add(:media, "must be images or videos") unless media.all? { |m| m.content_type.to_s.start_with?("image/", "video/") }
    end
end
