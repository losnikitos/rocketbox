# frozen_string_literal: true

# A prompt applied to one library media. The result is a photobank media, created up front so a running or
# failed generation already has a page; GenerateJob attaches its file when the AI call finishes.
# `options` start from the prompt's (see GenerationOptions). `extra_prompt` is appended to the prompt body.
class Generation < ApplicationRecord
  include GenerationOptions

  STATUSES = %w[running complete failed].freeze

  belongs_to :source_media, class_name: "LibraryMedia", inverse_of: :generations
  belongs_to :prompt
  belongs_to :generated_media, class_name: "LibraryMedia", inverse_of: :origin

  validates :status, inclusion: { in: STATUSES }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def video? = prompt&.video?

  def inherited_options = prompt&.options

  # Raises ActiveRecord::RecordInvalid on bad options, before the photobank media is created.
  def start!
    build_generated_media(user: source_media.user, kind: video? ? "video" : "photo", collection: "photobank",
      media_type: source_media.media_type)
    save!
    GenerateJob.perform_later(self)
    self
  end

  # One AI call on the source image.
  def run!
    opts = ai_options
    prompt_text = [ prompt.body, extra_prompt ].compact_blank.join("\n\n")
    provider_options = opts.except(:provider, :model)
    source = source_media.file.blob
    if video?
      result = RubyLLM.animate(prompt_text, model: opts[:model], provider: opts[:provider], with: source, provider_options:)
      file = { io: StringIO.new(result.to_blob), filename: "ai-video.mp4", content_type: "video/mp4" }
    else
      result = RubyLLM.paint(prompt_text, model: opts[:model], provider: opts[:provider], with: source, provider_options:)
      self.cost = result.cost.total
      file = { io: StringIO.new(result.to_blob), filename: "ai-image.jpg", content_type: "image/jpeg" }
    end
    generated_media.update!(kind: video? ? "video" : "photo", file:)
    update!(status: "complete")
  rescue StandardError => e
    Rails.logger.error("[Generation] id=#{id} #{e.class}: #{e.message}")
    update!(status: "failed", error: e.message.to_s.truncate(1000))
  end
end
