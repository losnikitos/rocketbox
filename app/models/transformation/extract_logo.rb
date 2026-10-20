# frozen_string_literal: true

# Paints a logo from a business-card or sign photo into the step's output folder (photobank/logo).
# Skips (fails the step) when the image has no graphic logo, so a sibling Update business can still finish.
class Transformation::ExtractLogo < Transformation::Generation
  def self.label = "Extract logo"

  def self.description = "Pulls a logo from a business card or sign photo into Photobank / Logo."

  def self.inputs = { image: 1..1 }

  HAS_LOGO_PROMPT = "Does this photo show a graphic logo or brand mark (not just plain text on a card)? " \
    "has_logo is true only for a real mark or emblem."
  HAS_LOGO_SCHEMA = {
    type: "object",
    properties: { has_logo: { type: "boolean" } },
    required: [ "has_logo" ],
    additionalProperties: false
  }.freeze
  DEFAULT_BODY = "Extract only the logo from this photo (a business card, shop sign, or storefront). Output the logo alone, " \
    "centered on a plain white square background, with its original colors and shapes preserved. Remove all other text, " \
    "contact details, card edges, surroundings, shadows, and background. Do not redesign or add anything."

  def file
    raise "No logo found" unless has_logo?

    result = RubyLLM.paint(run.prompt_text, with: images, **ai_args)
    run.cost = (run.cost || 0) + result.cost.total
    attachment(result.to_blob, "jpg", "image/jpeg")
  end

  private

    def has_logo?
      chat = RubyLLM.chat(provider: :xai).with_schema(HAS_LOGO_SCHEMA)
      info = chat.ask(HAS_LOGO_PROMPT, with: source_media.first.file).parsed
      run.cost = (run.cost || 0) + chat.cost.total
      info["has_logo"] == true
    end
end
