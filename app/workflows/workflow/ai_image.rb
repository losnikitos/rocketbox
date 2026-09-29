# frozen_string_literal: true

class Workflow
  # Image + prompt => new image, once per input image.
  class AiImage
    LABEL = "AI image"
    ICON = "sparkles"

    def self.call(inputs:, params:, run:)
      prompt = Prompt.body_for!(params["prompt"])
      inputs.map do |blob|
        { io: StringIO.new(Xai.edit_image(prompt:, blob:)), filename: "ai-image.jpg", content_type: "image/jpeg" }
      end
    end
  end
end
