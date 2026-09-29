# frozen_string_literal: true

class Transition < Workflow
  step :photos, Input, slot: "all"
  step :video, AiVideo, from: :photos, prompt: :transition_video
  step :reel, Output, from: :video, format: "reel"
end
