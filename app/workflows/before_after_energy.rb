# frozen_string_literal: true

class BeforeAfterEnergy < Workflow
  step :photos, Input, slot: "all"
  step :video, AiVideo, from: :photos, prompt: "Turn these photos into a dynamic vertical Instagram Reel. Start on the first image, then transition through the rest with energetic cuts and subtle motion. Emphasize craftsmanship and transformation. Clean, premium, ready for Instagram Reels. No captions or logos."
  step :reel, Output, from: :video, format: "reel"
end
