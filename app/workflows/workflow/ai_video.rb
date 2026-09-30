# frozen_string_literal: true

class Workflow
  # Images + prompt => one vertical video (the first image animated, or several as references).
  class AiVideo
    LABEL = "AI video"
    ICON = "film"
    SCHEME = %i[prompt video].freeze

    def self.call(inputs:, params:, run:)
      [ { io: StringIO.new(Xai.generate_video(prompt: params["prompt"], blobs: inputs, **run.subject.xai_options, stopped: -> { run.reload.stopped? })), filename: "ai-video.mp4", content_type: "video/mp4" } ]
    end
  end
end
