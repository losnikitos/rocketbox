# frozen_string_literal: true

class Workflow
  # Image + prompt => new image, once per input image.
  class AiImage
    LABEL = "AI image"
    ICON = "sparkles"
    SCHEME = %i[prompt image].freeze

    def self.call(inputs:, params:, run:)
      inputs.map do |blob|
        { io: StringIO.new(Xai.edit_image(prompt: params["prompt"], blob:, **run.subject.xai_options)), filename: "ai-image.jpg", content_type: "image/jpeg" }
      end
    end
  end
end
