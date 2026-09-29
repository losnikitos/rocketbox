# frozen_string_literal: true

class BeforeAfterEnergy < Workflow
  step :photos, Input, slot: "all"
  step :video, AiVideo, from: :photos, prompt: :before_after_energy_video
  step :reel, Output, from: :video, format: "reel"
end
