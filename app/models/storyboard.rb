# frozen_string_literal: true

# Coded promo storyboard (Rocketbox advertising itself — not customer SMM workflows).
# Settings (StoryboardSetting) drive videos/source/rules; scenes previewed in Studio; renders → MP4.
class Storyboard
  Scene = Data.define(:slug, :kind, :label, :image, :from, :to, :text, :href) do
    def still? = kind == :still
    def overlay? = kind == :overlay
    def transition? = kind == :transition
    def cta? = kind == :cta
    def renderable? = still? || overlay? || cta?
  end

  # /app/media_bank/:id (optional host) — paste from Studio Media bank (#244).
  MEDIA_BANK = %r{\A(?:https?://[^/]+)?/app/media_bank/(\d+)/?\z}

  attr_reader :slug, :name, :size, :guide_slug

  def initialize(slug:, name:, size:, guide_slug:)
    @slug, @name, @size, @guide_slug = slug, name, size, guide_slug
  end

  GUIDE_PROMO = new(
    slug: "guide-promo",
    name: "Guide promo",
    size: [ 1080, 1920 ],
    guide_slug: "barbershop"
  ).freeze

  ALL = [ GUIDE_PROMO ].freeze

  def self.find(slug) = ALL.find { it.slug == slug } || raise(ActiveRecord::RecordNotFound)

  def to_param = slug

  def settings = StoryboardSetting.for(self)

  def default_settings
    {
      transition_type: "simple_fade",
      cta_text: "Comment “guide”",
      cta_href: "/guides/#{guide_slug}",
      overlays: [
        { "number" => 10, "text" => "Keep the facade clear" },
        { "number" => 12, "text" => "Use warm light" }
      ],
      videos: [
        {
          "source" => "/guides/barbershop/cluttered.jpg",
          "rules" => [ 10, 12 ],
          # Optional after frames per rule (demo compare set). Custom media-bank videos omit these.
          "afters" => [ "/guides/barbershop/clean.jpg", "/guides/barbershop/warm.jpg" ]
        }
      ]
    }
  end

  def scenes(video_index: 0) = build_scenes(settings, video_index:)

  def find_scene(slug, video_index: 0)
    scenes(video_index:).find { it.slug == slug } || raise(ActiveRecord::RecordNotFound)
  end

  def template_for(scene) = "accounts/storyboards/scenes/#{scene.kind}"

  # Data URL for Ferrum; preview URL (public path or blob) for the iframe / film strip.
  def background_for(scene, data_url: false)
    path = scene.image || scene.from
    return unless path

    data_url ? self.class.image_data_url(path) : self.class.preview_url(path)
  end

  def self.preview_url(source)
    if (id = media_bank_id(source))
      media = LibraryMedia.bank.find_by(id:)
      return Rails.application.routes.url_helpers.rails_blob_path(media.file, only_path: true) if media&.file&.attached?
    end
    source
  end

  def self.image_data_url(source)
    bytes, mime = image_bytes(source)
    "data:#{mime};base64,#{Base64.strict_encode64(bytes)}"
  end

  # Writes a readable file path into `dir` (tmpdir for bank blobs / copies).
  def self.resolve_file!(source, dir:)
    if (id = media_bank_id(source))
      media = LibraryMedia.bank.find(id)
      raise Errno::ENOENT, source unless media.file.attached?

      ext = File.extname(media.file.filename.to_s).presence || ".jpg"
      path = File.join(dir, "bank-#{id}#{ext}")
      File.binwrite(path, media.file.download)
      return path
    end

    file = Rails.root.join("public", source.to_s.delete_prefix("/"))
    raise Errno::ENOENT, source unless file.file?

    path = File.join(dir, "public-#{File.basename(file)}")
    FileUtils.cp(file, path)
    path
  end

  def self.media_bank_id(source) = MEDIA_BANK.match(source.to_s)&.[](1)

  def self.image_bytes(source)
    if (id = media_bank_id(source))
      media = LibraryMedia.bank.find(id)
      raise Errno::ENOENT, source unless media.file.attached?

      return [ media.file.download, media.file.content_type.presence || "image/jpeg" ]
    end

    file = Rails.root.join("public", source.to_s.delete_prefix("/"))
    raise Errno::ENOENT, source unless file.file?

    [ file.binread, Marcel::MimeType.for(extension: file.extname) ]
  end

  def self.data_url(public_path) = image_data_url(public_path)

  def self.screenshot(html, size:) = Layer.screenshot(html, size:)

  private

    def build_scenes(settings, video_index:)
      video = settings.video_at(video_index)
      source = video["source"].to_s
      rules = Array(video["rules"]).map(&:to_i)
      afters = Array(video["afters"])
      scenes = []
      current = source

      scenes << Scene.new(slug: "v0", kind: :still, label: "v0 — source",
        image: current, from: nil, to: nil, text: nil, href: nil)

      rules.each_with_index do |number, i|
        text = settings.overlay_text(number).presence || "Rule ##{number}"
        scenes << Scene.new(slug: "overlay-#{number}", kind: :overlay, label: "Overlay · rule ##{number}",
          image: current, from: nil, to: nil, text: "Applying rule ##{number}\n#{text}", href: nil)

        nxt = afters[i].presence
        next if nxt.blank? || nxt == current

        scenes << Scene.new(slug: "transition-#{i}", kind: :transition, label: "Transition → v#{i + 1}",
          image: nil, from: current, to: nxt, text: nil, href: nil)
        current = nxt
        scenes << Scene.new(slug: "v#{i + 1}", kind: :still, label: "v#{i + 1}",
          image: current, from: nil, to: nil, text: nil, href: nil)
      end

      scenes << Scene.new(slug: "cta", kind: :cta, label: "CTA — guide",
        image: current, from: nil, to: nil, text: settings.cta_text, href: settings.cta_href)
      scenes
    end
end
