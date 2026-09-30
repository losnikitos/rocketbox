# frozen_string_literal: true

class RunWorkflowJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: ->(run_id) { run_id }, duration: 15.minutes
  discard_on ActiveRecord::RecordNotFound

  def perform(run_id)
    WorkflowRun.find(run_id).advance!
  end
end
