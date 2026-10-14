# frozen_string_literal: true

# Runs a media that just landed in its folder through the autorun workflows starting there (see Workflow.autorun!).
# One landing in the Inbox root is sorted into a subfolder first, landing it again there.
class AutorunWorkflowsJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(media)
    return unless media.user && media.file.attached?
    return if media.folder == Folder.inbox && SortInboxMedia.call(media)

    Workflow.autorun!(media)
  end
end
