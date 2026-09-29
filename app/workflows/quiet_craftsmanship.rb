# frozen_string_literal: true

class QuietCraftsmanship < Workflow
  step :photos, Input, slot: "all"
  step :video, AiVideo, from: :photos, prompt: "Generate a calm vertical Instagram Reel from these photos. Soft push-ins, gentle ambient motion, and a refined editorial feel that highlights skill and detail. Keep the scene faithful to the source images. No text overlays."
  step :reel, Output, from: :video, format: "reel"
end
