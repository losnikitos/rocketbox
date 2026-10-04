# frozen_string_literal: true

class SmmPost < ApplicationRecord
  STATUSES = %w[draft generating ready published failed].freeze
  REACTIONS = %w[up down].freeze
  belongs_to :user
  # The review a Reviews feature post shows.
  belongs_to :review, optional: true
  has_many :smm_post_media_items, -> { order(:position) }, dependent: :destroy, inverse_of: :smm_post
  has_many :library_media, through: :smm_post_media_items
  has_many :smm_slides, -> { order(:position) }, dependent: :destroy

  # A multi-slide post is a carousel; a multi-slide story publishes as several stories.
  enum :format, %w[post story reel].index_by(&:itself), validate: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  normalizes :reaction, :reaction_comment, with: ->(value) { value.strip.presence }
  validates :reaction, inclusion: { in: REACTIONS }, allow_nil: true

  scope :recent, -> { order(created_at: :desc) }

  after_update_commit :broadcast_refresh, if: :saved_change_to_status?

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

  def mark_published!
    update!(status: "published", published_at: Time.current, error_message: nil)
  end

  def feature = (Feature.find(feature_slug) if feature_slug)

  # A feature post renders its layer over its photo.
  def generate!
    smm_slides.create!(media: { io: StringIO.new(feature.render(self)), filename: "#{feature_slug}.png", content_type: "image/png" })
    update!(status: "ready", error_message: nil)
  rescue StandardError => e
    Rails.logger.error("[SmmPost#generate!] id=#{id} #{e.class}: #{e.message}")
    update!(status: "failed", error_message: e.message.to_s.truncate(1000))
  end
end
