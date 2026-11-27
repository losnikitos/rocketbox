# frozen_string_literal: true

# Coded promo preset (Rocketbox advertising itself — not customer SMM workflows).
# Hard-coded overlays, CTA, transition and scene formula; Posts supply source + rules + frames.
# Formula for guide-promo: before → (overlay → frame)* → cta. No index/show UI — referenced by id.
class Preset
  Scene = Data.define(:slug, :kind, :label, :image, :from, :to, :text, :href) do
    def still? = kind == :still
    def overlay? = kind == :overlay
    def transition? = kind == :transition
    def cta? = kind == :cta
    def renderable? = still? || overlay? || cta?
  end

  Overlay = Data.define(:number, :text)

  TRANSITIONS = { "simple_fade" => "Simple fade" }.freeze

  attr_reader :slug, :name, :size, :guide_slug, :transition_type, :cta_text, :cta_href, :overlays

  def initialize(slug:, name:, size:, guide_slug:, transition_type:, cta_text:, cta_href:, overlays:)
    @slug = slug
    @name = name
    @size = size
    @guide_slug = guide_slug
    @transition_type = transition_type
    @cta_text = cta_text
    @cta_href = cta_href
    @overlays = overlays.map { Overlay.new(**it) }.freeze
  end

  GUIDE_PROMO = new(
    slug: "guide-promo",
    name: "Guide promo",
    size: [ 1080, 1920 ],
    guide_slug: "barbershop",
    transition_type: "simple_fade",
    cta_text: "Comment “guide”",
    cta_href: "/guides/barbershop",
    overlays: [
      { number: 10, text: "Keep the facade clear" },
      { number: 12, text: "Use warm light" }
    ]
  ).freeze

  ALL = [ GUIDE_PROMO ].freeze

  def self.find(slug) = ALL.find { it.slug == slug } || raise(ActiveRecord::RecordNotFound)

  def to_param = slug

  def overlay_text(number)
    overlays.find { it.number == number.to_i }&.text.to_s
  end

  def rule_numbers = overlays.map(&:number)

  def transition_label = TRANSITIONS.fetch(transition_type)

  # Scenes for a Post: 1..n selected rules → matching overlay (+ optional frame) scenes, then CTA.
  # image/from/to are LibraryMedia (bank) or PostFrame records; missing frames → overlay stacks on current.
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
      next unless frame&.file&.attached?
      next if frame == current

      scenes << Scene.new(slug: "transition-#{i}", kind: :transition, label: "Transition → v#{i + 1}",
        image: nil, from: current, to: frame, text: nil, href: nil)
      current = frame
      scenes << Scene.new(slug: "v#{i + 1}", kind: :still, label: "v#{i + 1}",
        image: current, from: nil, to: nil, text: nil, href: nil)
    end

    scenes << Scene.new(slug: "cta", kind: :cta, label: "CTA — guide",
      image: current, from: nil, to: nil, text: cta_text, href: cta_href)
    scenes
  end


  def find_scene(slug, post:)
    scenes_for(post).find { it.slug == slug } || raise(ActiveRecord::RecordNotFound)
  end

  def template_for(scene) = "accounts/presets/scenes/#{scene.kind}"

  # Data URL for Ferrum; preview URL (blob) for the iframe / film strip.
  def background_for(scene, data_url: false)
    ref = scene.image || scene.from
    return unless ref

    data_url ? self.class.image_data_url(ref) : self.class.preview_url(ref)
  end

  def self.preview_url(ref)
    return unless (attachment = resolve_attachment(ref))

    Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
  end

  def self.image_data_url(ref)
    bytes, mime = image_bytes(ref)
    "data:#{mime};base64,#{Base64.strict_encode64(bytes)}"
  end

  def self.resolve_attachment(ref)
    file = ref.try(:file)
    file if file&.attached?
  end

  def self.image_bytes(ref)
    attachment = resolve_attachment(ref) or raise Errno::ENOENT, ref.inspect
    [ attachment.download, attachment.content_type.presence || "image/jpeg" ]
  end

  def self.screenshot(html, size:) = Layer.screenshot(html, size:)

  def default_post_attrs
    {
      preset_slug: slug,
      source: "",
      rules: rule_numbers
    }
  end
end
