# frozen_string_literal: true

class ExtractBusinessCard
  LOGO_MODEL = "grok-imagine-image-2.0"
  NULLABLE_STRING = { type: %w[string null] }.freeze
  SCHEMA = {
    type: "object",
    properties: {
      **LibraryMedia::CARD_FIELDS.keys.index_with { NULLABLE_STRING },
      has_logo: { type: "boolean" }
    },
    required: [ *LibraryMedia::CARD_FIELDS.keys, "has_logo" ],
    additionalProperties: false
  }.freeze

  def self.call(media:)
    new(media:).call
  end

  def initialize(media:)
    @media = media
  end

  def call
    raise ArgumentError, "Only images can be read." unless @media.story_image?

    info = RubyLLM.chat(provider: :xai)
      .with_schema(SCHEMA)
      .ask(Prompt.body_for!(:business_card_info), with: @media.file)
      .parsed
    has_logo = info.delete("has_logo") == true

    @media.extracted_logo.purge
    extract_logo! if has_logo

    @media.update!(extracted_info: { "status" => "done", "fields" => info.slice(*LibraryMedia::CARD_FIELDS.keys), "has_logo" => has_logo })
  rescue RubyLLM::Error, Faraday::Error => e
    fail!(e)
  rescue StandardError => e
    fail!(e)
    raise
  end

  private

    def extract_logo!
      image = RubyLLM.paint(Prompt.body_for!(:business_card_logo), model: LOGO_MODEL, provider: :xai, with: @media.file)
      @media.extracted_logo.attach(
        io: StringIO.new(image.to_blob),
        filename: "logo-#{@media.id}.#{image.mime_type.split("/").last}",
        content_type: image.mime_type
      )
    end

    def fail!(error)
      @media.update!(extracted_info: { "status" => "failed", "error" => error.message })
    end
end
