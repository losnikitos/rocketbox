# frozen_string_literal: true

class SeedGuideRuleImagePrompts < ActiveRecord::Migration[8.1]
  PROMPTS = {
    10 => <<~PROMPT.squish,
      Keep the same camera angle, building, signage, and surroundings as the source photo.
      Apply: Keep the facade clear — a tidy shop reads as professional; one sign on the facade,
      no sticker collage. Remove ALL window stickers, posters, special-offer signs, price lists,
      haircut photo grids, and decals from the glass door and windows so the glass is clear and
      you can see cleanly into the shop interior. Keep only the main overhead shop sign.
      Professional clear storefront, no clutter on the glass.
    PROMPT
    12 => <<~PROMPT.squish
      Keep the same camera angle, composition, and scene as the source photo.
      Apply: Use warm light — warm light flatters skin and wood; cool light makes everything
      clinical; prefer warm bulbs in the chair area. Replace cool blue-white LEDs with warm
      golden amber tungsten pendant and bulb light. Soft warm glow on wood tones and skin.
      No cold blue neon strips. Change only the lighting.
    PROMPT
  }.freeze

  def up
    guide = Guide.find_by(slug: "barbershop") or return
    PROMPTS.each do |number, prompt|
      guide.rules.where(number:).update_all(prompt:)
    end
  end

  def down
    guide = Guide.find_by(slug: "barbershop") or return
    guide.rules.where(number: PROMPTS.keys).update_all(prompt: "")
  end
end
