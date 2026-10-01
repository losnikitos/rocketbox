# frozen_string_literal: true

class ExtractBusinessCard
  LOGO_MODEL = "grok-imagine-image-2.0"
  INFO_PROMPT = <<~TEXT.strip
    You are reading a photo of a business card for a small business.
    Extract only what is printed on the card. Every field is optional: return null for anything not clearly present. Never guess or invent values.
    - business_name: the business or brand name.
    - phone: the main phone number, as printed.
    - person_name: the full name of the person on the card, if any.
    - address: the full street address on one line.
    - website: the website URL (add https:// if the scheme is missing). Not an email or social handle.
    - business_description: a short one-sentence description of what the business does, based on the card's tagline or services. Null if the card gives no hint.
    - has_logo: true if the card shows a graphic logo or brand mark (not just plain text), otherwise false.
  TEXT
  LOGO_PROMPT = "Extract only the logo from this photo (a business card, shop sign, or storefront). Output the logo alone, " \
    "centered on a plain white square background, with its original colors and shapes preserved. Remove all other text, " \
    "contact details, card edges, surroundings, shadows, and background. Do not redesign or add anything."
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

  def self.extract_logo!(media)
    image = RubyLLM.paint(LOGO_PROMPT, model: LOGO_MODEL, provider: :xai, with: media.file)
    media.extracted_logo.attach(
      io: StringIO.new(image.to_blob),
      filename: "logo-#{media.id}.#{image.mime_type.split("/").last}",
      content_type: image.mime_type
    )
  end

  def initialize(media:)
    @media = media
  end

  def call
    raise ArgumentError, "Only images can be read." unless @media.story_image?

    info = RubyLLM.chat(provider: :xai)
      .with_schema(SCHEMA)
      .ask(INFO_PROMPT, with: @media.file)
      .parsed
    has_logo = info.delete("has_logo") == true

    @media.extracted_logo.purge
    self.class.extract_logo!(@media) if has_logo

    @media.update!(extracted_info: { "status" => "done", "fields" => info.slice(*LibraryMedia::CARD_FIELDS.keys), "has_logo" => has_logo })
  rescue RubyLLM::Error, Faraday::Error => e
    fail!(e)
  rescue StandardError => e
    fail!(e)
    raise
  end

  private

    def fail!(error)
      @media.update!(extracted_info: { "status" => "failed", "error" => error.message })
    end
end
