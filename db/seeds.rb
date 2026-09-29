# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

{
  "Transition A->B" => "Transition",
  "Cinematic shop reel" => "CinematicShopReel",
  "Before → after energy" => "BeforeAfterEnergy",
  "Quiet craftsmanship" => "QuietCraftsmanship",
  "Bank holiday story" => "BankHolidayStory"
}.each { |name, workflow| Recipe.find_or_initialize_by(name:).update!(workflow:) }

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
    name: "Extract logo",
    body: "Extract only the logo from this photo (a business card, shop sign, or storefront). Output the logo alone, centered on a plain white square background, with its original colors and shapes preserved. Remove all other text, contact details, card edges, surroundings, shadows, and background. Do not redesign or add anything."
  },
  {
    key: "crawl_business",
    name: "Crawl: extract business profile",
    body: <<~PROMPT
      This page is about a small local business (its own website, a Google Maps listing, a booking page like Fresha or Booksy, or a social profile).
      Extract the business profile and media we can reuse on its Instagram. Only use what the page shows; leave a field empty rather than guess.
      - business_name: the business name, without the platform name or location suffix unless it is part of the brand.
      - phone: the main phone number, as shown.
      - address: the full street address on one line.
      - website: the business's own website. Not the page being crawled, a booking platform, a map, or a social profile.
      - business_description: one or two sentences on what the business does and what makes it stand out.
      - business_hours: opening hours, one line per day or day range, e.g. "Mon–Fri 9am–6pm".
      - logo_url: direct URL of the business's logo or brand mark, if shown. Never a photo of the premises, food, work, or people; leave empty if there is no actual logo.
      - photo_urls: direct URLs of photos of the business itself: finished work, interior, exterior, team. Prefer the largest available size. Skip icons, maps, avatars of reviewers, stock images, and placeholders.
      - video_urls: direct URLs of video files (.mp4, .mov, .webm) of the business, if any.
    PROMPT
  }
].each do |attrs|
  prompt = Prompt.find_or_initialize_by(key: attrs[:key])
  prompt.assign_attributes(name: attrs[:name], body: attrs[:body].strip, active: true)
  prompt.save!
end

# Meta app review account (credentials are shared with the submission).
User.find_or_initialize_by(email: "review@meta.com").update!(password: "review_2026", verified: true)
