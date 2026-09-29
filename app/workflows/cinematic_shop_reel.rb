# frozen_string_literal: true

class CinematicShopReel < Workflow
  step :photos, Input, slot: "all"
  step :video, AiVideo, from: :photos, prompt: :cinematic_shop_reel_video
  step :reel, Output, from: :video, format: "reel"
end
