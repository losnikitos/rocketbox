# frozen_string_literal: true

class Transition < Workflow
  step :photos, Input, slot: "all"
  step :video, AiVideo, from: :photos, prompt: "Create a transition between provided images"
  step :reel, Output, from: :video, format: "reel"
end
