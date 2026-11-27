# frozen_string_literal: true

# Coded promo preset (Rocketbox advertising itself — not customer SMM workflows).
# Subclasses define CTA, scene formula and other hard-coded bits; Posts hold settings.
# No index/show UI — referenced by slug.
class Preset
  SIZE = [ 1080, 1920 ].freeze

  Scene = Data.define(:slug, :kind, :label, :image, :from, :to, :text, :href) do
    def still? = kind == :still
    def overlay? = kind == :overlay
    def transition? = kind == :transition
    def cta? = kind == :cta
    def renderable? = still? || overlay? || cta?
  end

  Overlay = Data.define(:number, :text)

  TRANSITIONS = { "simple_fade" => "Simple fade" }.freeze

  def self.all = [ GuidePromo.new ]

  def self.find(slug) = all.find { it.slug == slug } || raise(ActiveRecord::RecordNotFound)

  def size = SIZE

  def to_param = slug

  def overlay_text(number)
    overlays.find { it.number == number.to_i }&.text.to_s
  end

  def self.transition_label(type) = TRANSITIONS.fetch(type)

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

  def scenes_for(post) = raise NotImplementedError, "#{self.class}#scenes_for"
  def default_post_attrs = raise NotImplementedError, "#{self.class}#default_post_attrs"
  def overlays = raise NotImplementedError, "#{self.class}#overlays"
  def slug = raise NotImplementedError, "#{self.class}#slug"
  def name = raise NotImplementedError, "#{self.class}#name"
end
