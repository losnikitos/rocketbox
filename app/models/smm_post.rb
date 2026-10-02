# frozen_string_literal: true

class SmmPost < ApplicationRecord
  STATUSES = %w[draft generating ready published failed].freeze
  REACTIONS = %w[up down].freeze
  # Instagram feed takes 4:5 at most; providers without it get a square.
  ASPECT_RATIOS = { "story" => "9:16", "reel" => "9:16", "post" => "4:5" }.freeze
  belongs_to :user
  belongs_to :recipe, optional: true
  has_many :smm_post_media_items, -> { order(:position) }, dependent: :destroy, inverse_of: :smm_post
  has_many :library_media, through: :smm_post_media_items
  has_many :smm_slides, -> { order(:position) }, dependent: :destroy

  # A multi-slide post is a carousel; a multi-slide story publishes as several stories.
  enum :format, %w[post story reel].index_by(&:itself), validate: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :reaction, inclusion: { in: REACTIONS }, allow_nil: true
  validate :media_fit_recipe, on: :create, if: :recipe

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

  def mark_published!
    update!(status: "published", published_at: Time.current, error_message: nil)
  end

  # One AI call composing the recipe's photos into the post's single slide.
  def generate!
    model = RubyLLM::ActiveRecord::Model.enabled.where(provider: Generation::IMAGE_OPTIONS.keys).find { it.type == :image }
    raise "No image model is enabled." unless model

    ratio = ASPECT_RATIOS.fetch(format)
    ratio = "1:1" unless ratio.in?(Generation::IMAGE_OPTIONS.dig(model.provider, "aspect_ratio"))
    provider_options = case model.provider
    when "openai" then { size: Generation::OPENAI_SIZES.dig(ratio, "2k"), output_format: "jpeg" }
    when "gemini" then { generationConfig: { imageConfig: { aspectRatio: ratio, imageSize: "2K" } } }
    else { aspect_ratio: ratio, resolution: "2k" }
    end
    result = RubyLLM.paint(recipe.body, model: model.model_id, provider: model.provider.to_sym,
      with: smm_post_media_items.map { it.library_media.file.blob }, provider_options:)
    smm_slides.create!(media: { io: StringIO.new(result.to_blob), filename: "recipe.jpg", content_type: "image/jpeg" })
    update!(status: "ready", error_message: nil)
  rescue StandardError => e
    Rails.logger.error("[SmmPost#generate!] id=#{id} #{e.class}: #{e.message}")
    update!(status: "failed", error_message: e.message.to_s.truncate(1000))
  end

  private

    def media_fit_recipe
      media = smm_post_media_items.map(&:library_media)
      fits = media.size == recipe.media_type_ids.size && media.uniq.size == media.size &&
        media.zip(recipe.media_type_ids).all? { |item, type_id| item.photobank? && item.user_id == user_id && item.media_type_id == type_id && item.story_image? }
      errors.add(:base, "Pick a different photobank photo for every slot.") unless fits
    end
end
