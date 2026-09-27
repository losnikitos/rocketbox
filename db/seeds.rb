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

[
  {
    key: "business_card_info",
    name: "Business card: extract info",
    body: <<~PROMPT
      You are reading a photo of a business card for a small business.
      Extract only what is printed on the card. Every field is optional: return null for anything not clearly present. Never guess or invent values.
      - business_name: the business or brand name.
      - phone: the main phone number, as printed.
      - person_name: the full name of the person on the card, if any.
      - address: the full street address on one line.
      - website: the website URL (add https:// if the scheme is missing). Not an email or social handle.
      - business_description: a short one-sentence description of what the business does, based on the card's tagline or services. Null if the card gives no hint.
      - has_logo: true if the card shows a graphic logo or brand mark (not just plain text), otherwise false.
    PROMPT
  },
  {
    key: "business_card_logo",
    name: "Business card: extract logo",
    body: "Extract only the logo from this business card. Output the logo alone, centered on a plain white square background, with its original colors and shapes preserved. Remove all other text, contact details, card edges, shadows, and background. Do not redesign or add anything."
  }
].each do |attrs|
  prompt = Prompt.find_or_initialize_by(key: attrs[:key])
  prompt.assign_attributes(name: attrs[:name], body: attrs[:body].strip, active: true)
  prompt.save!
end
