# frozen_string_literal: true

# How a transformation makes its media, picked by the transformation's `kind`, a type's slug. Each type is a class: what
# it is as class methods (label, description, layer, …), how it makes a run's file as `file` on an instance wrapping the run.
# Its superclass is its group: Generation (one AI call), Overlay (a layer over one photo or video), Edit (one photo or
# video edited) or Scripted (the inputs cut into a reel, each type its own folder under reels/). A new type is a
# subclass plus a line in `all`.
class Transformation::Type
  def self.all = [
    Transformation::GenerateImage, Transformation::GenerateVideo,
    Transformation::FullyBooked, Transformation::Daily, Transformation::Review, Transformation::Calendar,
    Transformation::SmartCrop,
    Reels::Steps, Reels::Doppler, Reels::Welcome, Reels::BlackEyedPeas, Reels::Azzurro, Reels::GmVisuals
  ]

  def self.find(slug) = all.find { it.slug == slug }

  def self.slug = name.demodulize.underscore

  def self.group = superclass

  def self.description = nil

  # A 2:3 image picturing the type, 400x600: a scripted type's original's first frame, an overlay's layer over a gradient.
  def self.cover = "transformations/#{slug}.jpg"

  def self.layer = nil

  def self.ai? = false

  def self.video? = false

  # Takes one photo or video and makes the same.
  def self.single? = false

  def self.reel? = false

  # A workflow step's named inputs, in the order their media reach the run (see WorkflowRun), or nil for one open input.
  def self.slots = nil

  def self.takes_review? = false

  attr_reader :run

  delegate :transformation, :source_media, to: :run

  def initialize(run)
    @run = run
  end

  private

    # `<kind>_<run id>.<ext>`, e.g. generate_image_3.jpg.
    def attachment(bytes, ext, content_type) = { io: StringIO.new(bytes), filename: "#{transformation.kind}_#{run.id}.#{ext}", content_type: }

    # PNG bytes: the layer over the first source media, cropped to the layer's size, filled from `values`
    # (the run's review's, if any). Transparent behind the layer when `over_photo` is false.
    def layer_png(over_photo: true, values: run.review&.layer_values || {})
      layer = self.class.layer
      if over_photo
        photo = source_media.first.file.variant(resize_to_fill: layer.size, format: :jpeg).processed
        background = "data:image/jpeg;base64,#{Base64.strict_encode64(photo.download)}"
      end
      html = Current.set(account: run.generated_media.user) do
        ApplicationController.render("accounts/layers/canvas", layout: false,
          assigns: { layer:, values: layer.values(values) }, locals: { background: })
      end
      Layer.screenshot(html, size: layer.size)
    end

    def ffmpeg!(*args)
      log, status = Open3.capture2e("ffmpeg", "-y", "-loglevel", "error", *args)
      raise "ffmpeg failed: #{log.lines.last(3).join.strip.presence || status}" unless status.success?
    end
end
