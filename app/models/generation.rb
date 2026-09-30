# frozen_string_literal: true

# A recipe applied to one library media. The result is a photobank media, created up front so a running or
# failed generation already has a page; the workflow attaches its file when it finishes.
# `options` are the provider request options (IMAGE_OPTIONS or VIDEO_OPTIONS) for every AI step; the chosen
# model picks the provider.
class Generation < ApplicationRecord
  # Allowed values per provider and request option. Omitted options use the provider's default.
  IMAGE_OPTIONS = {
    "xai" => {
      "model" => %w[grok-imagine-image-2.0 grok-imagine-image-quality grok-imagine-image],
      "aspect_ratio" => %w[1:1 16:9 9:16 4:3 3:4 3:2 2:3 2:1 1:2 19.5:9 9:19.5 20:9 9:20 21:9 5:2],
      "resolution" => %w[1k 2k],
      "quality" => %w[low medium] # grok-imagine-image-2.0 only
    },
    "openai" => {
      "model" => %w[gpt-image-2 gpt-image-1.5 gpt-image-1-mini],
      "size" => %w[1024x1024 1024x1536 1536x1024],
      "quality" => %w[low medium high]
    }
  }.freeze
  VIDEO_OPTIONS = {
    "xai" => {
      "model" => %w[grok-imagine-video-1.5 grok-imagine-video],
      "aspect_ratio" => %w[1:1 16:9 9:16 4:3 3:4 3:2 2:3],
      "resolution" => %w[480p 720p 1080p], # 1080p on grok-imagine-video-1.5 only
      "duration" => (1..15).map(&:to_s)
    }
  }.freeze

  belongs_to :source_media, class_name: "LibraryMedia", inverse_of: :generations
  belongs_to :recipe
  belongs_to :generated_media, class_name: "LibraryMedia", inverse_of: :origin
  has_one :workflow_run, as: :subject, dependent: :destroy

  delegate :status, :error, to: :workflow_run, allow_nil: true

  after_initialize if: -> { new_record? && recipe } do
    self.options = default_options.merge(options)
  end
  before_validation { self.options = options.to_h.slice(*option_choices.keys).compact_blank }
  validate do
    options.each { |key, value| errors.add(:options, "#{key.humanize} #{value} isn't available") unless value.in?(option_choices[key]) }
  end

  def video? = recipe&.format == "reel"

  def option_sets = video? ? VIDEO_OPTIONS : IMAGE_OPTIONS

  def provider = option_sets.keys.find { option_sets[it]["model"].include?(options["model"]) } || option_sets.keys.first

  # Every provider's models are offered; the other choices come from the chosen model's provider.
  def option_choices = option_sets[provider].merge("model" => option_sets.values.flat_map { it["model"] })

  def ai_options
    options.symbolize_keys.tap { it[:duration] = it[:duration].to_i if it[:duration] }.merge(provider: provider.to_sym)
  end

  # Raises ActiveRecord::RecordInvalid on bad options, before the photobank media is created.
  def start!
    build_generated_media(user: source_media.user, kind: video? ? "video" : "photo", collection: "photobank",
      media_type: source_media.media_type)
    save!
    WorkflowRun.start!(self)
    self
  end

  def input_media = [ source_media ]

  # Status lives on the workflow run.
  def mark_generating! = nil
  def mark_ready! = nil
  def mark_failed!(_message) = nil

  # Re-runs replace the previous file.
  def store_output!(blobs, _format)
    blob = blobs.first or raise Workflow::Error, "The recipe produced no media."
    generated_media.update!(kind: LibraryMedia.kind_for(blob.content_type), file: blob)
    [ blob ]
  end

  private

    def default_options
      model = options["model"].presence || (video? ? RubyLLM.config.default_video_model : RubyLLM.config.default_image_model)
      return { "model" => model, "size" => "1024x1536" } if provider == "openai"

      defaults = { "model" => model, "aspect_ratio" => recipe.format == "post" ? "3:4" : "9:16" }
      defaults.merge!(Workflow::AiVideo::DEFAULTS.slice(:resolution, :duration).stringify_keys.transform_values(&:to_s)) if video?
      defaults
    end
end
