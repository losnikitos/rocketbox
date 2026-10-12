# frozen_string_literal: true

class Transformation::Daily < Transformation::Overlay
  def self.label = "Daily"

  def self.description = "The time and a caption, over one photo or video."

  def self.layer = Layer.find("daily")

  def self.inputs = { media: 1..1, prompt: 0..1 }

  private

    # The prompt fed to it, if any, is the caption.
    def layer_png(over_photo: true)
      caption = run.prompts.first&.body&.strip.presence
      super(over_photo:, values: transformation.layer_steps.first.to_h.symbolize_keys.merge({ caption: }.compact))
    end
end
