# frozen_string_literal: true

class SmmPost < ApplicationRecord
  STATUSES = %w[draft generating ready published failed].freeze
  REACTIONS = %w[up down].freeze
  MAX_MEDIA = 7

  belongs_to :user
  belongs_to :recipe
  has_many :smm_post_media_items, -> { order(:position) }, dependent: :destroy, inverse_of: :smm_post
  has_many :library_media, through: :smm_post_media_items
  has_many :smm_slides, -> { order(:position) }, dependent: :destroy
  has_one :workflow_run, as: :subject, dependent: :destroy

  # A multi-slide post is a carousel; a multi-slide story publishes as several stories.
  enum :format, %w[post story reel].index_by(&:itself), validate: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :reaction, inclusion: { in: REACTIONS }, allow_nil: true
  # On create only: deleting library media later can leave a post with no media.
  validate :media_count_within_limits, on: :create
  validate :media_must_be_images, on: :create

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

  def carousel?
    post? && smm_slides.size > 1
  end

  def publishable?
    ready? && smm_slides.any? { it.media.attached? }
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

  def input_media
    smm_post_media_items.includes(library_media: { file_attachment: :blob }).map(&:library_media)
  end

  def xai_options = {}

  # The workflow's output media become the slides.
  def store_output!(blobs, format)
    media = blobs.map { it.video? ? it : MediaCanvas.fit(it, format) }
    transaction do
      smm_slides.destroy_all
      media.each_with_index { |item, index| smm_slides.create!(position: index, media: item) }
      update!(format:)
    end
    smm_slides.map { it.media.blob }
  end

  private

    def media_count_within_limits
      count = smm_post_media_items.size
      expected = recipe&.input_count
      if count < 1
        errors.add(:base, "Select at least one image from your library.")
      elsif count > MAX_MEDIA
        errors.add(:base, "Select at most #{MAX_MEDIA} images.")
      elsif expected && count != expected
        errors.add(:base, "#{recipe.name} needs exactly #{expected} #{"image".pluralize(expected)}.")
      end
    end

    def media_must_be_images
      smm_post_media_items.each do |item|
        media = item.library_media
        next if media.blank?
        next if media.story_image?

        errors.add(:base, "Only images can be used as recipe inputs.")
        break
      end
    end
end
