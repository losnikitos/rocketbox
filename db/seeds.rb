# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

[
  {
    name: "Cinematic shop reel",
    body: "Create a vertical Instagram Reel for a local small business. Animate the reference photos into a polished cinematic clip with smooth camera moves, warm natural light, and a confident social-media look. Keep the people and products recognizable. No text overlays.",
    position: 1
  },
  {
    name: "Before → after energy",
    body: "Turn these photos into a dynamic vertical Instagram Reel. Start on the first image, then transition through the rest with energetic cuts and subtle motion. Emphasize craftsmanship and transformation. Clean, premium, ready for Instagram Reels. No captions or logos.",
    position: 2
  },
  {
    name: "Quiet craftsmanship",
    body: "Generate a calm vertical Instagram Reel from these photos. Soft push-ins, gentle ambient motion, and a refined editorial feel that highlights skill and detail. Keep the scene faithful to the source images. No text overlays.",
    position: 3
  }
].each do |attrs|
  prompt = Prompt.find_or_initialize_by(name: attrs[:name])
  prompt.assign_attributes(body: attrs[:body], active: true, position: attrs[:position])
  prompt.save!
end
