# frozen_string_literal: true

# Moves one photo or video into one of the folders this step feeds (vision pick; Misc when none fits).
# The step run's result is the same LibraryMedia — no copy. Destinations are the outbound folder edges.
# Its prompt (`body`) and chat model are edited in the inspector like other AI steps.
class Transformation::Sort < Transformation::Control
  def self.label = "Sort"

  def self.description = "Files media into one of the folders it's connected to."

  def self.single? = true

  def self.relocates? = true

  def self.ai? = true

  # Vision classify via chat (+ schema), not an image generator.
  def self.chat? = true

  DEFAULT_BODY = SortInboxMedia::PROMPT

  # Folder the source media should move to.
  def folder
    folders = destinations
    model = run.options["model"]
    SortInboxMedia.classify(
      source_media.first,
      folders:,
      prompt: run.prompt_text.presence || self.class::DEFAULT_BODY,
      model:,
      provider: run.provider
    )
  end

  private

    def destinations
      node = run.workflow_node or return []
      node.workflow.edges.select { it.from_id == node.id }.filter_map { it.to.folder }
    end
end
