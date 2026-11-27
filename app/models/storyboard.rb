# frozen_string_literal: true

# Coded promo storyboard (Rocketbox advertising itself — not customer SMM workflows).
# A fixed sequence of stills, overlays, video transitions and a CTA; previewed scene-by-scene
# under Admin Studio. Stills compose via Ferrum (same as Layer); transitions stub until a video API run.
class Storyboard
  Scene = Data.define(:slug, :kind, :label, :image, :from, :to, :text, :href) do
    def still? = kind == :still
    def overlay? = kind == :overlay
    def transition? = kind == :transition
    def cta? = kind == :cta
    def renderable? = still? || overlay? || cta?
  end

  attr_reader :slug, :name, :size, :scenes, :guide_slug

  def initialize(slug:, name:, size:, guide_slug:, scenes:)
    @slug, @name, @size, @guide_slug, @scenes = slug, name, size, guide_slug, scenes
  end

  # Barbershop guide promo: cluttered → clear facade → warm light → CTA to the guide.
  GUIDE_PROMO = new(
    slug: "guide-promo",
    name: "Guide promo",
    size: [ 1080, 1920 ],
    guide_slug: "barbershop",
    scenes: [
      Scene.new(slug: "v0", kind: :still, label: "v0 — before",
        image: "/guides/barbershop/cluttered.jpg", from: nil, to: nil, text: nil, href: nil),
      Scene.new(slug: "overlay-10", kind: :overlay, label: "Overlay · rule #10",
        image: "/guides/barbershop/cluttered.jpg", from: nil, to: nil,
        text: "Applying rule #10\nKeep the facade clear", href: nil),
      Scene.new(slug: "transition-v0-v1", kind: :transition, label: "Transition v0 → v1",
        image: nil, from: "/guides/barbershop/cluttered.jpg", to: "/guides/barbershop/clean.jpg",
        text: nil, href: nil),
      Scene.new(slug: "v1", kind: :still, label: "v1 — clear facade",
        image: "/guides/barbershop/clean.jpg", from: nil, to: nil, text: nil, href: nil),
      Scene.new(slug: "overlay-12", kind: :overlay, label: "Overlay · rule #12",
        image: "/guides/barbershop/clean.jpg", from: nil, to: nil,
        text: "Applying rule #12\nUse warm light", href: nil),
      Scene.new(slug: "transition-v1-v2", kind: :transition, label: "Transition v1 → v2",
        image: nil, from: "/guides/barbershop/clean.jpg", to: "/guides/barbershop/warm.jpg",
        text: nil, href: nil),
      Scene.new(slug: "v2", kind: :still, label: "v2 — warm light",
        image: "/guides/barbershop/warm.jpg", from: nil, to: nil, text: nil, href: nil),
      Scene.new(slug: "cta", kind: :cta, label: "CTA — guide",
        image: "/guides/barbershop/warm.jpg", from: nil, to: nil,
        text: "Comment “guide”", href: "/guides/barbershop")
    ].freeze
  ).freeze

  ALL = [ GUIDE_PROMO ].freeze

  def self.find(slug) = ALL.find { it.slug == slug } || raise(ActiveRecord::RecordNotFound)

  def to_param = slug

  def find_scene(slug) = scenes.find { it.slug == slug } || raise(ActiveRecord::RecordNotFound)

  def template_for(scene) = "accounts/storyboards/scenes/#{scene.kind}"

  # Data URL for Ferrum (no asset server); public path for the preview iframe.
  def background_for(scene, data_url: false)
    path = scene.image || scene.from
    return unless path

    data_url ? self.class.data_url(path) : path
  end

  def self.data_url(public_path)
    file = Rails.root.join("public", public_path.delete_prefix("/"))
    raise Errno::ENOENT, public_path unless file.file?

    mime = Marcel::MimeType.for(extension: file.extname)
    "data:#{mime};base64,#{Base64.strict_encode64(file.binread)}"
  end

  def self.screenshot(html, size:) = Layer.screenshot(html, size:)
end
