# frozen_string_literal: true

# Guide promo: before → (overlay → frame)×n → CTA. Settings: source, rules, transition_type.
# Overlay copy comes from the guide's rules; CTA is hard-coded here.
class Preset::GuidePromo < Preset
  SLUG = "guide-promo"
  NAME = "Guide promo"
  GUIDE_SLUG = "barbershop"
  CTA_TEXT = "Comment “guide”"
  CTA_HREF = "/guides/barbershop"
  DEFAULT_TRANSITION = "simple_fade"

  def slug = SLUG
  def name = NAME
  def guide_slug = GUIDE_SLUG
  def cta_text = CTA_TEXT
  def cta_href = CTA_HREF

  def guide = Guide.find_by!(slug: guide_slug)

  def overlays
    guide.rules.map { Overlay.new(number: it.number, text: it.title) }
  end

  def default_post_attrs
    {
      preset_slug: slug,
      source: "",
      rules: [],
      transition_type: DEFAULT_TRANSITION
    }
  end

  # Scenes for a Post: source → (overlay → transition → frame)* → CTA.
  # Missing/unattached frames stay in the strip as empty (gray) stills.
  def scenes_for(post)
    rules = Array(post.rules).map(&:to_i)
    scenes = []
    current = post.source_media

    scenes << Scene.new(slug: "v0", kind: :still, label: "v0 — source",
      image: current, from: nil, to: nil, text: nil, href: nil)

    rules.each_with_index do |number, i|
      text = overlay_text(number).presence || "Rule ##{number}"
      scenes << Scene.new(slug: "overlay-#{number}", kind: :overlay, label: "Overlay · rule ##{number}",
        image: current, from: nil, to: nil, text: "Applying rule ##{number}\n#{text}", href: nil)

      frame = post.frame_at(i + 1)
      next_ref = frame&.file&.attached? ? frame : nil

      scenes << Scene.new(slug: "transition-#{i}", kind: :transition, label: "Transition → v#{i + 1}",
        image: nil, from: current, to: next_ref, text: nil, href: nil)
      current = next_ref
      scenes << Scene.new(slug: "v#{i + 1}", kind: :still, label: "v#{i + 1}",
        image: current, from: nil, to: nil, text: nil, href: nil)
    end

    scenes << Scene.new(slug: "cta", kind: :cta, label: "CTA — guide",
      image: current, from: nil, to: nil, text: cta_text, href: cta_href)
    scenes
  end
end
