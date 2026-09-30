# frozen_string_literal: true

# A recipe applied to one library media. The result is a photobank media, created up front so a running or
# failed generation already has a page; the workflow attaches its file when it finishes.
class Generation < ApplicationRecord
  belongs_to :source_media, class_name: "LibraryMedia", inverse_of: :generations
  belongs_to :recipe
  belongs_to :generated_media, class_name: "LibraryMedia", inverse_of: :origin
  has_one :workflow_run, as: :subject, dependent: :destroy

  delegate :status, :error, to: :workflow_run, allow_nil: true

  def self.start!(source_media, recipe)
    generation = transaction do
      generated_media = LibraryMedia.create!(user: source_media.user, kind: recipe.format == "reel" ? "video" : "photo",
        collection: "photobank", media_type: source_media.media_type)
      create!(source_media:, recipe:, generated_media:)
    end
    WorkflowRun.start!(generation)
    generation
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
end
