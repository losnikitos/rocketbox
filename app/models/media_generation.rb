# frozen_string_literal: true

class MediaGeneration < ApplicationRecord
  MEDIA_MODELS = {
    "image" => [ "grok-imagine-image-2.0", "grok-imagine-image-quality" ].freeze,
    "video" => [ "grok-imagine-video-1.5" ].freeze
  }.freeze

  belongs_to :user, optional: true
  has_one_attached :file

  enum :status, { in_progress: 0, succeeded: 1, failed: 2 }, default: :in_progress

  before_validation :infer_media_type

  validates :prompt, presence: true
  validates :media_type, inclusion: { in: MEDIA_MODELS.keys }
  validates :model, presence: true
  validate :model_allowed_for_media_type

  def self.model_options
    MEDIA_MODELS.flat_map do |type, models|
      models.map { |m| [ "#{type}: #{m}", m ] }
    end
  end

  def self.media_type_for(model)
    MEDIA_MODELS.find { |_type, models| models.include?(model) }&.first
  end

  def image?
    media_type == "image"
  end

  def video?
    media_type == "video"
  end

  private

    def infer_media_type
      inferred = self.class.media_type_for(model)
      self.media_type = inferred if inferred
    end

    def model_allowed_for_media_type
      allowed = MEDIA_MODELS[media_type]
      return if allowed&.include?(model)

      errors.add(:model, "is not allowed for #{media_type}")
    end
end
