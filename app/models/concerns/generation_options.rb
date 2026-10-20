# frozen_string_literal: true

# AI request options in an `options` JSON column: the model (one of `models`, enabled in Active Admin) picks the
# provider, the rest are that provider's IMAGE_OPTIONS or VIDEO_OPTIONS (none for an LLM's chat model). New records start from `inherited_options`
# (a transformation run from its transformation), then the defaults below. Includers define `video?` and `type`.
module GenerationOptions
  extend ActiveSupport::Concern

  # Allowed values per provider and request option. Omitted options use the provider's default.
  # Aspect ratios are our own short list (what the shapes picker draws), not everything a provider takes.
  IMAGE_OPTIONS = {
    "xai" => {
      "aspect_ratio" => %w[9:16 1:1 4:3 16:9],
      "resolution" => %w[1k 2k],
      "quality" => %w[low medium] # grok-imagine-image-2.0 only
    },
    "openai" => {
      "aspect_ratio" => %w[9:16 4:5 1:1 4:3 16:9],
      "resolution" => %w[1k 2k 4k],
      "quality" => %w[low medium high]
    },
    "gemini" => {
      "aspect_ratio" => %w[9:16 4:5 1:1 4:3 16:9],
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
      "aspect_ratio" => %w[9:16 1:1 4:3 16:9],
      "resolution" => %w[480p 720p 1080p], # 1080p on grok-imagine-video-1.5 only
      "duration" => (1..15).map(&:to_s)
    },
    "gemini" => {
      "aspect_ratio" => %w[9:16 16:9],
      "resolution" => %w[720p 1080p], # 1080p needs 8s
      "duration" => %w[4 6 8]
    },
    "openrouter" => {
      "aspect_ratio" => %w[9:16 1:1 16:9],
      "resolution" => %w[720p 1080p], # 1080p not on Kling / Runway
      "duration" => %w[4 5 6 8 10]
    }
  }.freeze
  # A prompt-writing type picks just the model.
  CHAT_OPTIONS = { "xai" => {}, "openai" => {}, "gemini" => {} }.freeze
  # Offered by every provider.
  IMAGE_DEFAULTS = { "aspect_ratio" => "9:16", "resolution" => "2k" }.freeze
  VIDEO_DEFAULTS = { "aspect_ratio" => "9:16", "resolution" => "720p", "duration" => "8" }.freeze
  # Product-level frame roles (Start / End / Refs), not provider field names. Fallback when model.metadata["video"] is empty.
  VIDEO_FIRST_FRAME_ONLY = %w[runway/gen-4.5].freeze
  # Models that accept reference images (OpenRouter input_references / Gemini referenceImages). Hand-maintained.
  VIDEO_WITH_REFS = %w[
    bytedance/seedance-1-5-pro
    bytedance/seedance-2.0-fast
    bytedance/seedance-2.5
    kwaivgi/kling-v3.0-std
    kwaivgi/kling-v3.0-pro
    black-forest-labs/flux-3-video
  ].freeze
  # Per-model allowlists intersected with the provider's VIDEO_OPTIONS (fallback when metadata has no video options).
  VIDEO_MODEL_OPTIONS = {
    "runway/gen-4.5" => { "aspect_ratio" => %w[9:16 16:9], "resolution" => %w[720p], "duration" => %w[4 5 6 8 10] },
    "kwaivgi/kling-v3.0-std" => { "aspect_ratio" => %w[9:16 1:1 16:9], "resolution" => %w[720p], "duration" => %w[4 5 6 8 10] },
    "kwaivgi/kling-v3.0-pro" => { "aspect_ratio" => %w[9:16 1:1 16:9], "resolution" => %w[720p], "duration" => %w[4 5 6 8 10] },
    "bytedance/seedance-2.5" => { "aspect_ratio" => %w[9:16 1:1 16:9], "resolution" => %w[720p], "duration" => %w[4 5 6 8 10] },
    "bytedance/seedance-2.0-fast" => { "aspect_ratio" => %w[9:16 1:1 16:9], "resolution" => %w[720p], "duration" => %w[4 5 6 8 10] },
    "bytedance/seedance-1-5-pro" => { "aspect_ratio" => %w[9:16 1:1 16:9], "resolution" => %w[720p 1080p], "duration" => %w[4 5 6 8 10] },
    "black-forest-labs/flux-3-video" => { "aspect_ratio" => %w[9:16 1:1 16:9], "resolution" => %w[720p 1080p], "duration" => %w[5 6 8 10] }
  }.freeze

  included do
    after_initialize :fill_options, if: :new_record?
    before_validation(if: :options_changed?) { self.options = options.to_h.slice(*option_choices.keys).compact_blank }
    validate(if: :options_changed?) do
      options.each { |key, value| errors.add(:options, "#{key.humanize} #{value} isn't available") unless value.in?(option_choices[key]) }
    end
  end

  # What image roles this video model accepts: :first always, :last / :refs when the product (or synced metadata) says so.
  def video_frame_roles
    return [] unless video?
    if (roles = selected_video_model&.metadata.to_h.dig("video", "frame_roles")).present?
      return roles.map(&:to_sym)
    end
    roles = %i[first]
    roles << :last unless VIDEO_FIRST_FRAME_ONLY.include?(options["model"])
    roles << :refs if video_model_allows_refs?
    roles
  end

  def supports_last_frame? = video_frame_roles.include?(:last)

  def supports_reference? = video_frame_roles.include?(:refs)

  def inherited_options = {}

  # The RubyLLM model type it picks from.
  def model_type = video? ? :video : type&.makes == :prompt ? :chat : :image

  def option_sets = { video: VIDEO_OPTIONS, chat: CHAT_OPTIONS }.fetch(model_type, IMAGE_OPTIONS)

  def models
    (@models ||= {})[model_type] ||= RubyLLM::ActiveRecord::Model.enabled.where(provider: option_sets.keys)
      .select { it.type == model_type }
      .sort_by.with_index { |model, i| [ model.price_band || 4, i ] } # cheapest first, unbanded last
  end

  def provider = (models.find { it.model_id == options["model"] } || models.first)&.provider || option_sets.keys.first

  # Every provider's models are offered; the other choices come from the chosen model's provider, narrowed by
  # per-model allowlists (metadata or VIDEO_MODEL_OPTIONS). A type with its own options offers just those.
  def option_choices
    return type.options if type&.options
    base = { "model" => models.map(&:model_id) }.merge(option_sets[provider] || {})
    return base unless video? && (narrow = video_model_option_allowlist).present?

    base.merge(narrow) { |_key, provider_vals, model_vals| Array(provider_vals) & Array(model_vals) }
  end

  # Drops what the chosen model doesn't offer (e.g. after a model or kind switch), then fills the gaps
  # from the inherited options and the defaults; blank means Auto. A type's own options default to their first value.
  def fill_options
    given, inherited = options.to_h, inherited_options.to_h
    if (own = type&.options)
      return self.options = own.to_h { |key, values| [ key, [ given[key], inherited[key] ].find { it.in?(values) } || values.first ] }
    end
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
    # Gemini's Veo rejects generateAudio, so only xAI can be asked for a silent video.
    opts[:generate_audio] = false if video? && provider == "xai"
    opts = gemini_options(opts) if provider == "gemini"
    opts.compact.merge(provider: provider.to_sym)
  end

  private

    def selected_video_model = models.find { it.model_id == options["model"] }

    def video_model_allows_refs?
      id = options["model"].to_s
      VIDEO_WITH_REFS.include?(id) || id.match?(/\Aveo/i) || id.include?("/veo")
    end

    # Per-model duration / resolution / aspect from synced metadata, else VIDEO_MODEL_OPTIONS.
    def video_model_option_allowlist
      meta = selected_video_model&.metadata.to_h["video"].to_h
      from_meta = {
        "aspect_ratio" => meta["aspect_ratio"],
        "resolution" => meta["resolution"],
        "duration" => meta["duration"]
      }.compact_blank
      from_meta.presence || VIDEO_MODEL_OPTIONS[options["model"]]
    end

    # Gemini takes raw request-body fields: Nano Banana's imageConfig, Veo's predict parameters.
    def gemini_options(opts)
      if video?
        { model: opts[:model], parameters: { aspectRatio: opts[:aspect_ratio], resolution: opts[:resolution], durationSeconds: opts[:duration] }.compact }
      else
        { model: opts[:model], generationConfig: { imageConfig: { aspectRatio: opts[:aspect_ratio], imageSize: opts[:resolution]&.upcase }.compact } }
      end
    end
end
