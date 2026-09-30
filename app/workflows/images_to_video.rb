# frozen_string_literal: true

class ImagesToVideo < Workflow
  step :photos, Input, slot: "all"
  step :video, AiVideo, from: :photos
  step :reel, Output, from: :video, format: "reel"
end
