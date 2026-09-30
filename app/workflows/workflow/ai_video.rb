# frozen_string_literal: true

class Workflow
  # Images + prompt => one vertical video, the first image animated.
  class AiVideo
    LABEL = "AI video"
    ICON = "film"
    SCHEME = %i[prompt video].freeze
    DEFAULTS = { aspect_ratio: "9:16", resolution: "720p", duration: 8 }.freeze

    def self.call(inputs:, params:, run:)
      options = DEFAULTS.merge(run.subject.ai_options)
      video = RubyLLM.animate(params["prompt"], model: options[:model], provider: options[:provider], with: inputs.first, provider_options: options.except(:provider, :model))
      [ { io: StringIO.new(video.to_blob), filename: "ai-video.mp4", content_type: "video/mp4" } ]
    end
  end
end
