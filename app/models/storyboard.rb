# frozen_string_literal: true

# Coded promo preset (Rocketbox advertising itself — not customer SMM workflows).
# Hard-coded overlays, CTA, transition and scene formula; Posts supply source + rules + frames.
# Formula for guide-promo: before → (overlay → frame)* → cta. No index/show UI — referenced by id.
class Storyboard
  Scene = Data.define(:slug, :kind, :label, :image, :from, :to, :text, :href) do
    def still? = kind == :still
    def overlay? = kind == :overlay
    def transition? = kind == :transition
    def cta? = kind == :cta
    def renderable? = still? || overlay? || cta?
  end

  Overlay = Data.define(:number, :text)

  # /app/media_bank/:id (optional host) — paste from Studio Media bank.
  MEDIA_BANK = %r{\A(?:https?://[^/]+)?/app/media_bank/(\d+)/?\z}
  POST_FRAME = %r{\Apost_frame/(\d+)\z}
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

  def default_source = "/guides/#{guide_slug}/cluttered.jpg"

  # Scenes for a Post: 1..n selected rules → matching overlay (+ optional frame) scenes, then CTA.
  # Frames come from PostFrame attachments; missing frames → overlay stacks on current image.
  def scenes_for(post)
    source = post.source.to_s
    rules = Array(post.rules).map(&:to_i)
    scenes = []
    current = source

    scenes << Scene.new(slug: "v0", kind: :still, label: "v0 — source",
      image: current, from: nil, to: nil, text: nil, href: nil)

    rules.each_with_index do |number, i|
      text = overlay_text(number).presence || "Rule ##{number}"
      scenes << Scene.new(slug: "overlay-#{number}", kind: :overlay, label: "Overlay · rule ##{number}",
        image: current, from: nil, to: nil, text: "Applying rule ##{number}\n#{text}", href: nil)

      frame = post.frame_at(i + 1)
      next unless frame&.file&.attached?

      nxt = frame.source_ref
      next if nxt == current

      scenes << Scene.new(slug: "transition-#{i}", kind: :transition, label: "Transition → v#{i + 1}",
        image: nil, from: current, to: nxt, text: nil, href: nil)
      current = nxt
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

  def template_for(scene) = "accounts/storyboards/scenes/#{scene.kind}"

  # Data URL for Ferrum; preview URL (public path or blob) for the iframe / film strip.
  def background_for(scene, data_url: false)
    path = scene.image || scene.from
    return unless path

    data_url ? self.class.image_data_url(path) : self.class.preview_url(path)
  end

  def self.preview_url(source)
    if (attachment = resolve_attachment(source))
      return Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
    end
    source
  end

  def self.image_data_url(source)
    bytes, mime = image_bytes(source)
    "data:#{mime};base64,#{Base64.strict_encode64(bytes)}"
  end

  # Writes a readable file path into `dir` (tmpdir for bank/frame blobs / copies).
  def self.resolve_file!(source, dir:)
    if (attachment = resolve_attachment(source))
      ext = File.extname(attachment.filename.to_s).presence || ".jpg"
      label = post_frame_id(source) ? "frame-#{post_frame_id(source)}" : "bank-#{media_bank_id(source)}"
      path = File.join(dir, "#{label}#{ext}")
      File.binwrite(path, attachment.download)
      return path
    end

    file = Rails.root.join("public", source.to_s.delete_prefix("/"))
    raise Errno::ENOENT, source unless file.file?

    path = File.join(dir, "public-#{File.basename(file)}")
    FileUtils.cp(file, path)
    path
  end

  def self.media_bank_id(source) = MEDIA_BANK.match(source.to_s)&.[](1)

  def self.post_frame_id(source) = POST_FRAME.match(source.to_s)&.[](1)

  def self.resolve_attachment(source)
    if (id = media_bank_id(source))
      media = LibraryMedia.bank.find_by(id:)
      return media.file if media&.file&.attached?
    elsif (id = post_frame_id(source))
      frame = PostFrame.find_by(id:)
      return frame.file if frame&.file&.attached?
    end
    nil
  end

  def self.image_bytes(source)
    if (attachment = resolve_attachment(source))
      return [ attachment.download, attachment.content_type.presence || "image/jpeg" ]
    end

    file = Rails.root.join("public", source.to_s.delete_prefix("/"))
    raise Errno::ENOENT, source unless file.file?

    [ file.binread, Marcel::MimeType.for(extension: file.extname) ]
  end

  def self.data_url(public_path) = image_data_url(public_path)

  def self.screenshot(html, size:) = Layer.screenshot(html, size:)

  def default_post_attrs
    {
      storyboard_slug: slug,
      source: default_source,
      rules: rule_numbers
    }
  end
end
