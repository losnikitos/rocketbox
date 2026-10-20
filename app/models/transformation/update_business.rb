# frozen_string_literal: true

# Reads contact fields from a business-card (or similar) photo and writes them onto the media's owner.
# Blank fields are skipped. Makes a prompt whose body is the extracted JSON for the run UI.
class Transformation::UpdateBusiness < Transformation::Generation
  def self.label = "Update business"

  def self.description = "Reads business details from a photo and updates the account."

  def self.inputs = { image: 1..1 }

  def self.makes = :prompt

  # Extracted JSON key => User column. Shown in the step's inspector settings.
  FIELDS = {
    "business_name" => :business_name,
    "phone" => :phone,
    "person_name" => :name,
    "address" => :address,
    "website" => :homepage_url,
    "business_description" => :business_description
  }.freeze

  def self.account_fields = FIELDS

  NULLABLE_STRING = { type: %w[string null] }.freeze
  SCHEMA = {
    type: "object",
    properties: FIELDS.keys.index_with { NULLABLE_STRING },
    required: FIELDS.keys,
    additionalProperties: false
  }.freeze

  DEFAULT_BODY = <<~TEXT.strip
    You are reading a photo of a business card for a small business.
    Extract only what is printed on the card. Every field is optional: return null for anything not clearly present. Never guess or invent values.
    - business_name: the business or brand name.
    - phone: the main phone number, as printed.
    - person_name: the full name of the person on the card, if any.
    - address: the full street address on one line.
    - website: the website URL (add https:// if the scheme is missing). Not an email or social handle.
    - business_description: a short one-sentence description of what the business does, based on the card's tagline or services. Null if the card gives no hint.
  TEXT

  def body
    model = run.options["model"]
    chat = RubyLLM.chat(model:, provider: (run.provider.to_sym if model)).with_schema(SCHEMA)
    info = chat.ask(run.prompt_text, with: source_media.first.file).parsed
    run.cost = chat.cost.total
    attrs = FIELDS.to_h { |key, column| [ column, info[key].to_s.strip ] }.compact_blank
    owner = source_media.first&.user
    owner&.update!(attrs) if attrs.any?
    JSON.pretty_generate(info.slice(*FIELDS.keys))
  end
end
