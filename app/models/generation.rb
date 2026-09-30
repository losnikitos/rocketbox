# frozen_string_literal: true

# A recipe applied to one library media. The result is a photobank media, created up front so a running or
# failed generation already has a page; the workflow attaches its file when it finishes.
# `options` are the xAI request options (Xai::IMAGE_OPTIONS or VIDEO_OPTIONS) for every AI step.
class Generation < ApplicationRecord
  belongs_to :source_media, class_name: "LibraryMedia", inverse_of: :generations
  belongs_to :recipe
  belongs_to :generated_media, class_name: "LibraryMedia", inverse_of: :origin
  has_one :workflow_run, as: :subject, dependent: :destroy

  delegate :status, :error, to: :workflow_run, allow_nil: true

  after_initialize if: -> { new_record? && recipe } do
    self.options = default_options.merge(options)
  end
  before_validation { self.options = options.to_h.slice(*option_choices.keys).compact_blank }
  validate do
    options.each { |key, value| errors.add(:options, "#{key.humanize} #{value} isn't available") unless value.in?(option_choices[key]) }
  end

  def video? = recipe&.format == "reel"

  def option_choices = video? ? Xai::VIDEO_OPTIONS : Xai::IMAGE_OPTIONS

  def xai_options
    options.symbolize_keys.tap { it[:duration] = it[:duration].to_i if it[:duration] }
  end

  # Raises ActiveRecord::RecordInvalid on bad options, before the photobank media is created.
  def start!
    build_generated_media(user: source_media.user, kind: video? ? "video" : "photo", collection: "photobank",
      media_type: source_media.media_type)
    save!
    WorkflowRun.start!(self)
    self
  end

  def input_media = [ source_media ]

  # Status lives on the workflow run.
  def mark_generating! = nil
  def mark_ready! = nil
  def mark_failed!(_message) = nil

  # Re-runs replace the previous file.
  def store_output!(blobs, _format)
    blob = blobs.first or raise Workflow::Error, "The recipe produced no media."
    generated_media.update!(kind: LibraryMedia.kind_for(blob.content_type), file: blob)
    [ blob ]
  end

  private

    def default_options
      defaults = { "model" => option_choices["model"].first, "aspect_ratio" => recipe.format == "post" ? "3:4" : "9:16" }
      defaults.merge!("resolution" => Xai::VIDEO_RESOLUTION, "duration" => Xai::VIDEO_DURATION.to_s) if video?
      defaults
    end
end
