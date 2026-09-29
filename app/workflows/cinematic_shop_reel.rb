# frozen_string_literal: true

class CinematicShopReel < Workflow
  step :photos, Input, slot: "all"
  step :video, AiVideo, from: :photos, prompt: "Create a vertical Instagram Reel for a local small business. Animate the reference photos into a polished cinematic clip with smooth camera moves, warm natural light, and a confident social-media look. Keep the people and products recognizable. No text overlays."
  step :reel, Output, from: :video, format: "reel"
end
