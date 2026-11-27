# frozen_string_literal: true

class SeedGuideRuleImagePrompts < ActiveRecord::Migration[8.1]
  PROMPTS = {
    10 => <<~PROMPT.squish,
      Inpaint edit of the reference photo only — leave every other pixel unchanged.
      Do not zoom, crop, reframe, or move the camera closer. Field of view must match the
      reference exactly (same upper facade, same sidewalk/road at the bottom, same neighbors).
      Only change: erase ALL stickers, posters, price lists, haircut photo grids, special-offer
      signs, and decals from the glass door and windows so the glass is clear. Keep the neon
      barber pole and the main overhead shop sign. No lighting change, no interior redesign.
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
