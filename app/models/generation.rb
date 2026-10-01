# frozen_string_literal: true

# A recipe applied to one library media. The result is a photobank media, created up front so a running or
# failed generation already has a page; GenerateJob attaches its file when the AI call finishes.
# `options` are the provider request options (IMAGE_OPTIONS or VIDEO_OPTIONS); the chosen
# model (one of `models`, enabled in Active Admin) picks the provider. `prompt` is appended to the recipe's prompt.
class Generation < ApplicationRecord
  STATUSES = %w[running complete failed].freeze

  # Allowed values per provider and request option. Omitted options use the provider's default.
  IMAGE_OPTIONS = {
    "xai" => {
      "aspect_ratio" => %w[1:1 16:9 9:16 4:3 3:4 3:2 2:3 2:1 1:2 19.5:9 9:19.5 20:9 9:20 21:9 5:2],
      "resolution" => %w[1k 2k],
      "quality" => %w[low medium] # grok-imagine-image-2.0 only
    },
    "openai" => {
      "aspect_ratio" => %w[9:16 4:5 1:1 16:9],
      "resolution" => %w[1k 2k 4k],
      "quality" => %w[low medium high]
    }
  }.freeze
  # OpenAI takes an exact size (gpt-image-2+ only: edges multiple of 16, 655,360..8,294,400 px, max 3840x2160;
  # above 2560x1440 is experimental). 1k ≈ 1 MP, 2k = 2560x1440 px, 4k = 3840x2160 px.
  OPENAI_SIZES = {
    "9:16" => { "1k" => "768x1360", "2k" => "1440x2560", "4k" => "2160x3840" },
    "4:5" => { "1k" => "912x1136", "2k" => "1712x2144", "4k" => "2576x3216" },
    "1:1" => { "1k" => "1024x1024", "2k" => "1920x1920", "4k" => "2880x2880" },
    "16:9" => { "1k" => "1360x768", "2k" => "2560x1440", "4k" => "3840x2160" }
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

  validates :status, inclusion: { in: STATUSES }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  # Keeps whatever the chosen model still offers (e.g. aspect ratio and quality across a model switch); blank means Auto.
  after_initialize if: -> { new_record? && recipe } do
    kept = options.to_h.select { |key, value| option_choices.key?(key) && (value.blank? || value.in?(option_choices[key])) }
    self.options = default_options.merge(kept)
  end
  before_validation { self.options = options.to_h.slice(*option_choices.keys).compact_blank }
  validate do
    options.each { |key, value| errors.add(:options, "#{key.humanize} #{value} isn't available") unless value.in?(option_choices[key]) }
  end

  def video? = recipe&.video?

  def option_sets = video? ? VIDEO_OPTIONS : IMAGE_OPTIONS

  def models
    @models ||= RubyLLM::ActiveRecord::Model.enabled.where(provider: option_sets.keys).select { it.type == (video? ? :video : :image) }
  end

  def provider = (models.find { it.model_id == options["model"] } || models.first)&.provider || option_sets.keys.first

  # Every provider's models are offered; the other choices come from the chosen model's provider.
  def option_choices = { "model" => models.map(&:model_id) }.merge(option_sets[provider])

  def ai_options
    opts = options.symbolize_keys.tap { it[:duration] = it[:duration].to_i if it[:duration] }
    opts[:size] = OPENAI_SIZES.dig(opts.delete(:aspect_ratio), opts.delete(:resolution)) if provider == "openai"
    opts.compact.merge(provider: provider.to_sym)
  end

  # Raises ActiveRecord::RecordInvalid on bad options, before the photobank media is created.
  def start!
    build_generated_media(user: source_media.user, kind: video? ? "video" : "photo", collection: "photobank",
      media_type: source_media.media_type)
    save!
    GenerateJob.perform_later(id)
    self
  end

  # One AI call on the source image.
  def run!
    opts = ai_options
    prompt_text = [ recipe.prompt, prompt ].compact_blank.join("\n\n")
    provider_options = opts.except(:provider, :model)
    source = source_media.file.blob
    if video?
      result = RubyLLM.animate(prompt_text, model: opts[:model], provider: opts[:provider], with: source, provider_options:)
      file = { io: StringIO.new(result.to_blob), filename: "ai-video.mp4", content_type: "video/mp4" }
    else
      provider_options[:output_format] = "jpeg" if opts[:provider] == :openai
      result = RubyLLM.paint(prompt_text, model: opts[:model], provider: opts[:provider], with: source, provider_options:)
      file = { io: StringIO.new(result.to_blob), filename: "ai-image.jpg", content_type: "image/jpeg" }
    end
    generated_media.update!(kind: video? ? "video" : "photo", file:)
    update!(status: "complete")
  rescue StandardError => e
    Rails.logger.error("[Generation] id=#{id} #{e.class}: #{e.message}")
    update!(status: "failed", error: e.message.to_s.truncate(1000))
  end

  private

    def default_options
      model = options["model"].presence || models.first&.model_id
      return { "model" => model, "aspect_ratio" => "9:16", "resolution" => "720p", "duration" => "8" } if video?

      { "model" => model, "aspect_ratio" => "9:16", "resolution" => "2k" }
    end
end
