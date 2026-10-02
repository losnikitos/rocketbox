# frozen_string_literal: true

# AI request options in an `options` JSON column: the model (one of `models`, enabled in Active Admin) picks the
# provider, the rest are that provider's IMAGE_OPTIONS or VIDEO_OPTIONS. New records start from `inherited_options`
# (a generation from its prompt, a recipe post from its recipe), then the defaults below. Includers define `video?`.
module GenerationOptions
  extend ActiveSupport::Concern

  # Allowed values per provider and request option. Omitted options use the provider's default.
  IMAGE_OPTIONS = {
    "xai" => {
      "aspect_ratio" => %w[1:1 16:9 9:16 4:3 3:4 3:2 2:3 2:1 1:2 19.5:9 9:19.5 20:9 9:20 21:9 5:2],
      "resolution" => %w[1k 2k],
      "quality" => %w[low medium] # grok-imagine-image-2.0 only
    },
    "openai" => {
      "aspect_ratio" => %w[9:16 4:5 1:1 4:3 16:9],
      "resolution" => %w[1k 2k 4k],
      "quality" => %w[low medium high]
    },
    "gemini" => {
      "aspect_ratio" => %w[1:1 2:3 3:2 3:4 4:3 4:5 5:4 9:16 16:9 21:9],
      "resolution" => %w[1k 2k 4k]
    }
  }.freeze
  # OpenAI takes an exact size (gpt-image-2+ only: edges multiple of 16, 655,360..8,294,400 px, max 3840x2160;
  # above 2560x1440 is experimental). 1k ≈ 1 MP, 2k = 2560x1440 px, 4k = 3840x2160 px.
  OPENAI_SIZES = {
    "9:16" => { "1k" => "768x1360", "2k" => "1440x2560", "4k" => "2160x3840" },
    "4:5" => { "1k" => "912x1136", "2k" => "1712x2144", "4k" => "2576x3216" },
    "1:1" => { "1k" => "1024x1024", "2k" => "1920x1920", "4k" => "2880x2880" },
    "4:3" => { "1k" => "1152x864", "2k" => "2240x1680", "4k" => "3264x2448" },
    "16:9" => { "1k" => "1360x768", "2k" => "2560x1440", "4k" => "3840x2160" }
  }.freeze
  VIDEO_OPTIONS = {
    "xai" => {
      "aspect_ratio" => %w[1:1 16:9 9:16 4:3 3:4 3:2 2:3],
      "resolution" => %w[480p 720p 1080p], # 1080p on grok-imagine-video-1.5 only
      "duration" => (1..15).map(&:to_s)
    },
    "gemini" => {
      "aspect_ratio" => %w[9:16 16:9],
      "resolution" => %w[720p 1080p], # 1080p needs 8s
      "duration" => %w[4 6 8]
    }
  }.freeze
  # Offered by every provider.
  IMAGE_DEFAULTS = { "aspect_ratio" => "9:16", "resolution" => "2k" }.freeze
  VIDEO_DEFAULTS = { "aspect_ratio" => "9:16", "resolution" => "720p", "duration" => "8" }.freeze

  included do
    after_initialize :fill_options, if: :new_record?
    before_validation(if: :options_changed?) { self.options = options.to_h.slice(*option_choices.keys).compact_blank }
    validate(if: :options_changed?) do
      options.each { |key, value| errors.add(:options, "#{key.humanize} #{value} isn't available") unless value.in?(option_choices[key]) }
    end
  end

  def inherited_options = {}

  def option_sets = video? ? VIDEO_OPTIONS : IMAGE_OPTIONS

  def models
    (@models ||= {})[video?] ||= RubyLLM::ActiveRecord::Model.enabled.where(provider: option_sets.keys).select { it.type == (video? ? :video : :image) }
  end

  def provider = (models.find { it.model_id == options["model"] } || models.first)&.provider || option_sets.keys.first

  # Every provider's models are offered; the other choices come from the chosen model's provider.
  def option_choices = { "model" => models.map(&:model_id) }.merge(option_sets[provider])

  # Drops what the chosen model doesn't offer (e.g. after a model or kind switch), then fills the gaps
  # from the inherited options and the defaults; blank means Auto.
  def fill_options
    given, inherited = options.to_h, inherited_options.to_h
    model_ids = models.map(&:model_id)
    self.options = { "model" => [ given["model"], inherited["model"] ].find { it.in?(model_ids) } || model_ids.first }
    choices = option_choices
    self.options = [ video? ? VIDEO_DEFAULTS : IMAGE_DEFAULTS, inherited, given ].reduce(options) do |kept, layer|
      kept.merge(layer.except("model").select { |key, value| choices.key?(key) && (value.blank? || value.in?(choices[key])) })
    end
  end

  def ai_options
    opts = options.symbolize_keys.tap { it[:duration] = it[:duration].to_i if it[:duration] }
    if provider == "openai"
      opts[:size] = OPENAI_SIZES.dig(opts.delete(:aspect_ratio), opts.delete(:resolution))
      opts[:output_format] = "jpeg"
    end
    opts = gemini_options(opts) if provider == "gemini"
    opts.compact.merge(provider: provider.to_sym)
  end

  private

    # Gemini takes raw request-body fields: Nano Banana's imageConfig, Veo's predict parameters.
    def gemini_options(opts)
      if video?
        { model: opts[:model], parameters: { aspectRatio: opts[:aspect_ratio], resolution: opts[:resolution], durationSeconds: opts[:duration] }.compact }
      else
        { model: opts[:model], generationConfig: { imageConfig: { aspectRatio: opts[:aspect_ratio], imageSize: opts[:resolution]&.upcase }.compact } }
      end
    end
end
