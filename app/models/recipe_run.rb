# frozen_string_literal: true

require "csv"

# A recipe applied to library media, one per recipe input. The result lands in the recipe's output folder, created
# up front so a running or failed run already has a page; GenerateJob attaches its file when the AI call finishes.
# A run without a recipe records a version the owner dropped onto a media themselves; it never runs.
# `options` start from the recipe's (see GenerationOptions).
# `prompt` is set on start from the recipe as given, so a run with unsaved edits sends them; it also keeps the text
# as sent, as the recipe, shot and style may change later.
class RecipeRun < ApplicationRecord
  include GenerationOptions

  STATUSES = %w[running complete failed].freeze
  # The Doppler stitch effect's track (.wav) and its cut ends in seconds (.csv).
  DOPPLER = Rails.root.join("lib/stitch/doppler").to_s

  belongs_to :recipe, optional: true
  belongs_to :shot, optional: true
  belongs_to :style, optional: true
  belongs_to :review, optional: true
  belongs_to :generated_media, class_name: "LibraryMedia", inverse_of: :recipe_run
  has_many :inputs, -> { order(:position) }, class_name: "RecipeRunInput", inverse_of: :recipe_run, dependent: :delete_all

  validates :status, inclusion: { in: STATUSES }
  validate :media_fit_recipe, on: :create, if: :recipe

  # The user's last recipe runs, for the Generations panel.
  scope :recent_for, ->(user) {
    where.not(recipe_id: nil).joins(:generated_media).where(library_media: { user_id: user.id })
      .includes(:recipe, generated_media: { file_attachment: :blob }).order(created_at: :desc).limit(5)
  }

  after_update_commit -> {
    broadcast_update_to [ generated_media.user, :generations ], target: "generations", partial: "layouts/app/generations", locals: { user: generated_media.user }
  }, if: :saved_change_to_status?
  after_update_commit :broadcast_refresh, if: :saved_change_to_status?

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def video? = recipe&.video?

  def inherited_options = recipe&.options

  # In slot order; also before save.
  def source_media = inputs.map(&:library_media)

  # `user` owns the result. Raises ActiveRecord::RecordInvalid when the media don't fit the slots, the shot doesn't fit
  # or an option isn't available.
  def start!(user)
    build_generated_media(user:, kind: recipe.video? || recipe.stitch? || layer_over_video? ? "video" : "photo", folder: recipe.output_folder)
    self.prompt = [ recipe.body, shot&.body, style&.body ].compact_blank.join("\n\n") if recipe.ai?
    save!
    GenerateJob.perform_later(self)
    self
  end

  # One AI call on the source media, a stitch of them, or a feature's layer over the first.
  def run!
    unless recipe.ai?
      file = if recipe.stitch? then { io: StringIO.new(stitch), filename: "recipe.mp4", content_type: "video/mp4" }
      elsif layer_over_video? then { io: StringIO.new(layer_video), filename: "#{recipe.layer_slug}.mp4", content_type: "video/mp4" }
      else { io: StringIO.new(layer_png), filename: "#{recipe.layer_slug}.png", content_type: "image/png" }
      end
      generated_media.update!(file:)
      return update!(status: "complete", error: nil)
    end
    opts = ai_options
    images = source_media.map { it.file.blob }
    args = { model: opts[:model], provider: opts[:provider], provider_options: opts.except(:provider, :model) }
    if video?
      result = RubyLLM.animate(prompt, with: images.first, **args)
      file = { io: StringIO.new(result.to_blob), filename: "recipe.mp4", content_type: "video/mp4" }
    else
      result = RubyLLM.paint(prompt, with: images.presence, **args)
      self.cost = result.cost.total
      file = { io: StringIO.new(result.to_blob), filename: "recipe.jpg", content_type: "image/jpeg" }
    end
    generated_media.update!(file:)
    update!(status: "complete", error: nil)
  rescue StandardError => e
    Rails.logger.error("[RecipeRun] id=#{id} #{e.class}: #{e.message}")
    update!(status: "failed", error: e.message.to_s.truncate(1000))
  end

  private

    # The source media as one 30fps MP4: 1 second each in order (a video's first second), or for the Doppler effect,
    # the Doppler track cut on its beat, each cut a random input other than the one before.
    # ponytail: fixed 9:16 1080x1920, and a video restarts from its first frame in every cut. Upgrade = aspect ratio
    # from the recipe options, a per-media offset.
    def stitch
      media = source_media
      doppler = recipe.effect == "doppler"
      # [media, frames] per cut. Ends are rounded to frames, not durations, so cuts don't drift off the beat.
      cuts = if doppler
        ends = CSV.foreach("#{DOPPLER}.csv", headers: true).map { (it["end"].to_f * 30).round }
        ends.zip([ 0, *ends ]).each_with_object([]) { |(stop, start), acc| acc << [ (media - [ acc.last&.first ]).sample || media.first, stop - start ] }
      else
        media.map { [ it, 30 ] }
      end
      Dir.mktmpdir do |dir|
        paths = media.each_with_index.to_h { |item, i| [ item, File.join(dir, i.to_s).tap { File.binwrite(it, item.file.download) } ] }
        fit = "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30,format=yuv420p"
        # One ffmpeg per cut, then a lossless join: a single graph with an input per cut queues frames for every
        # cut at once and got OOM-killed in production.
        list = File.join(dir, "cuts.txt")
        File.write(list, cuts.each_with_index.map do |(item, frames), i|
          segment = File.join(dir, "cut#{i}.mp4")
          # image2 reads the whole file as one frame; the default jpeg_pipe also emits embedded images (iPhone HDR gain
          # maps) as extra frames, and -loop 1 over those hangs ffmpeg.
          ffmpeg!(*(%w[-f image2 -loop 1] if item.story_image?), "-i", paths[item], "-vf", fit, "-frames:v", frames.to_s, "-an", "-c:v", "libx264", segment)
          "file '#{segment}'\n"
        end.join)
        audio_in, audio_out = [ "-i", "#{DOPPLER}.wav" ], [ "-map", "1:a", "-c:a", "aac" ] if doppler
        out = File.join(dir, "out.mp4")
        ffmpeg!("-f", "concat", "-safe", "0", "-i", list, *audio_in, "-map", "0:v", *audio_out, "-c:v", "copy", "-movflags", "+faststart", out)
        File.binread(out)
      end
    end

    def layer_over_video? = recipe.feature? && source_media.first&.video?

    # PNG bytes: the recipe's layer over the first source media, cropped to the layer's size, filled from the review if any.
    # Transparent behind the layer when `over_photo` is false.
    def layer_png(over_photo: true)
      layer = recipe.layer
      if over_photo
        photo = source_media.first.file.variant(resize_to_fill: layer.size, format: :jpeg).processed
        background = "data:image/jpeg;base64,#{Base64.strict_encode64(photo.download)}"
      end
      html = Current.set(account: generated_media.user) do
        ApplicationController.render("accounts/layers/canvas", layout: false,
          assigns: { layer:, values: layer.values(review&.layer_values || {}) }, locals: { background: })
      end
      Layer.screenshot(html, size: layer.size)
    end

    # MP4 bytes: the recipe's layer over the first source media, a video cropped to the layer's size, its sound kept.
    def layer_video
      width, height = recipe.layer.size
      Dir.mktmpdir do |dir|
        video, layer, out = %w[video layer.png out.mp4].map { File.join(dir, it) }
        File.binwrite(video, source_media.first.file.download)
        File.binwrite(layer, layer_png(over_photo: false))
        fit = "scale=#{width}:#{height}:force_original_aspect_ratio=increase,crop=#{width}:#{height},setsar=1"
        ffmpeg!("-i", video, "-i", layer, "-filter_complex", "[0:v]#{fit}[bg];[bg][1:v]overlay,format=yuv420p[v]",
          "-map", "[v]", "-map", "0:a?", "-c:v", "libx264", "-c:a", "aac", "-movflags", "+faststart", out)
        File.binread(out)
      end
    end

    def ffmpeg!(*args)
      log, status = Open3.capture2e("ffmpeg", "-y", "-loglevel", "error", *args)
      raise "ffmpeg failed: #{log.lines.last(3).join.strip.presence || status}" unless status.success?
    end

    def media_fit_recipe
      media = source_media
      fits = media.size == recipe.inputs.size && media.all? && media.all? { it.user_id == generated_media&.user_id } &&
        media.zip(recipe.inputs).all? { |item, slot| item.folder_id == slot["folder_id"] && recipe.takes?(item) }
      errors.add(:base, "Pick a matching photo for every input.") unless fits
      errors.add(:base, "Pick a shot from the recipe's shot group.") unless shot&.group == recipe.shot_group
      errors.add(:base, "Pick a review.") unless review.present? == recipe.takes_review? && (review.nil? || review.user_id == generated_media&.user_id)
    end
end
