# frozen_string_literal: true

class Workflow
  # Image + prompt => new image, once per input image.
  class AiImage
    LABEL = "AI image"
    ICON = "sparkles"
    SCHEME = %i[prompt image].freeze

    def self.call(inputs:, params:, run:)
      options = run.subject.xai_options
      inputs.map do |blob|
        image = RubyLLM.paint(params["prompt"], model: options[:model], provider: :xai, with: blob, provider_options: options.except(:model))
        { io: StringIO.new(image.to_blob), filename: "ai-image.jpg", content_type: "image/jpeg" }
      end
    end
  end
end
