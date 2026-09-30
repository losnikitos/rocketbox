# frozen_string_literal: true

# A recipe applied to one library media. The result is a photobank media, created up front so a running or
# failed generation already has a page; the workflow attaches its file when it finishes.
# `options` are the provider request options (IMAGE_OPTIONS or VIDEO_OPTIONS) for every AI step; the chosen
# model (one of `models`, enabled in Active Admin) picks the provider. `prompt` is appended to the recipe's prompt.
class Generation < ApplicationRecord
  # Allowed values per provider and request option. Omitted options use the provider's default.
  IMAGE_OPTIONS = {
    "xai" => {
      "aspect_ratio" => %w[1:1 16:9 9:16 4:3 3:4 3:2 2:3 2:1 1:2 19.5:9 9:19.5 20:9 9:20 21:9 5:2],
      "resolution" => %w[1k 2k],
      "quality" => %w[low medium] # grok-imagine-image-2.0 only
    },
    "openai" => {
      "size" => %w[1008x1792 1088x1360 1088x1088 1792x1008], # gpt-image-2+ only; 1.x models accept 3 fixed sizes
      "quality" => %w[low medium high]
    }
  }.freeze
  VIDEO_OPTIONS = {
    "xai" => {
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

  def models
    @models ||= RubyLLM::ActiveRecord::Model.enabled.where(provider: option_sets.keys).select { it.type == (video? ? :video : :image) }
  end

  def provider = (models.find { it.model_id == options["model"] } || models.first)&.provider || option_sets.keys.first

  # Every provider's models are offered; the other choices come from the chosen model's provider.
  def option_choices = { "model" => models.map(&:model_id) }.merge(option_sets[provider])

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
      model = options["model"].presence || models.first&.model_id
      return { "model" => model, "size" => recipe.format == "post" ? "1088x1360" : "1008x1792" } if provider == "openai"

      defaults = { "model" => model, "aspect_ratio" => recipe.format == "post" ? "3:4" : "9:16" }
      defaults.merge!(Workflow::AiVideo::DEFAULTS.slice(:resolution, :duration).stringify_keys.transform_values(&:to_s)) if video?
      defaults
    end
end
