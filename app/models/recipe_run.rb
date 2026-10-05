# frozen_string_literal: true

# A recipe applied to library media, one per recipe input. The result lands in the recipe's output folder, created
# up front so a running or failed run already has a page; GenerateJob attaches its file when the AI call finishes.
# A run without a recipe records a version the owner dropped onto a media themselves; it never runs.
# `options` start from the recipe's (see GenerationOptions). `extra_prompt` is appended to the recipe body.
# `prompt` keeps the text as sent, as the recipe, shot and style may change later.
class RecipeRun < ApplicationRecord
  include GenerationOptions

  STATUSES = %w[running complete failed].freeze

  belongs_to :recipe, optional: true
  belongs_to :shot, optional: true
  belongs_to :style, optional: true
  belongs_to :generated_media, class_name: "LibraryMedia", inverse_of: :recipe_run
  has_many :inputs, -> { order(:position) }, class_name: "RecipeRunInput", inverse_of: :recipe_run, dependent: :delete_all

  validates :status, inclusion: { in: STATUSES }
  validate :media_fit_recipe, on: :create, if: :recipe

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def video? = recipe&.video?

  def inherited_options = recipe&.options

  # In slot order; also before save.
  def source_media = inputs.map(&:library_media)

  # Raises ActiveRecord::RecordInvalid when the media don't fit the slots, the shot or style doesn't fit or an option isn't available.
  def start!
    first = source_media.first
    build_generated_media(user: first&.user, kind: recipe.generate_image? ? "photo" : "video", folder: recipe.output_folder)
    save!
    GenerateJob.perform_later(self)
    self
  end

  # One AI call on the source media, or a stitch of them.
  def run!
    if recipe.stitch?
      generated_media.update!(file: { io: StringIO.new(stitch), filename: "recipe.mp4", content_type: "video/mp4" })
      return update!(status: "complete", error: nil)
    end
    opts = ai_options
    self.prompt = [ recipe.body, shot&.body, style&.body, extra_prompt ].compact_blank.join("\n\n")
    images = source_media.map { it.file.blob }
    args = { model: opts[:model], provider: opts[:provider], provider_options: opts.except(:provider, :model) }
    if video?
      result = RubyLLM.animate(prompt, with: images.first, **args)
      file = { io: StringIO.new(result.to_blob), filename: "recipe.mp4", content_type: "video/mp4" }
    else
      result = RubyLLM.paint(prompt, with: images, **args)
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

    # The source media as one MP4, 1 second each (a video's first second).
    # ponytail: fixed 9:16 1080x1920 at 30fps, no audio. Upgrade = aspect ratio and duration from the recipe options.
    def stitch
      media = source_media
      Dir.mktmpdir do |dir|
        inputs = media.each_with_index.flat_map do |item, i|
          path = File.join(dir, i.to_s).tap { File.binwrite(it, item.file.download) }
          # image2 reads the whole file as one frame; the default jpeg_pipe also emits embedded images (iPhone HDR gain
          # maps) as extra frames, and -loop 1 over those hangs ffmpeg.
          [ *(%w[-f image2 -loop 1] if item.story_image?), "-t", "1", "-i", path ]
        end
        fit = "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30,format=yuv420p"
        filter = media.each_index.map { "[#{it}:v]#{fit}[v#{it}];" }.join + media.each_index.map { "[v#{it}]" }.join + "concat=n=#{media.size}:v=1:a=0[out]"
        out = File.join(dir, "out.mp4")
        log, status = Open3.capture2e("ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", filter,
          "-map", "[out]", "-c:v", "libx264", "-movflags", "+faststart", out)
        raise "ffmpeg failed: #{log.lines.last(3).join.strip}" unless status.success?
        File.binread(out)
      end
    end

    def media_fit_recipe
      media = source_media
      fits = media.size == recipe.inputs.size && media.all? && media.uniq.size == media.size && media.map(&:user_id).uniq.size == 1 &&
        media.zip(recipe.inputs).all? { |item, slot| item.folder_id == slot["folder_id"] && recipe.takes?(item) }
      errors.add(:base, "Pick a different matching photo for every input.") unless fits
      errors.add(:base, "Pick a shot from the recipe's shot group.") unless shot&.group == recipe.shot_group
      errors.add(:base, "Pick a style.") unless style.present? == recipe.takes_style?
    end
end
