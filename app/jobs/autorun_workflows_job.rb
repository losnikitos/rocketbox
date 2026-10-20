# frozen_string_literal: true

# Runs a media that just landed in its folder through the autorun workflows starting there (see Workflow.autorun!).
# Inbox-root landings go through the seeded Inbox sort workflow, which files them into a subfolder and lands again.
class AutorunWorkflowsJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(media)
    return unless media.user && media.file.attached?

    Workflow.autorun!(media)
  end
end
