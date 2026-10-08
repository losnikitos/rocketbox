# frozen_string_literal: true

# Runs a media that just landed in its folder through the autorun workflows starting there (see Workflow.autorun!).
class AutorunWorkflowsJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(media)
    Workflow.autorun!(media) if media.user && media.file.attached?
  end
end
