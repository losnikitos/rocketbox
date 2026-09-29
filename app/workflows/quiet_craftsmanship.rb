# frozen_string_literal: true

class QuietCraftsmanship < Workflow
  step :photos, Input, slot: "all"
  step :video, AiVideo, from: :photos, prompt: :quiet_craftsmanship_video
  step :reel, Output, from: :video, format: "reel"
end
