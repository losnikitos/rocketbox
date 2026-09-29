# frozen_string_literal: true

class Workflow
  # Images + prompt => one vertical video (the first image animated, or several as references).
  class AiVideo
    LABEL = "AI video"
    ICON = "film"

    def self.call(inputs:, params:, run:)
      [ { io: StringIO.new(Xai.generate_video(prompt: params["prompt"], blobs: inputs)), filename: "ai-video.mp4", content_type: "video/mp4" } ]
    end
  end
end
