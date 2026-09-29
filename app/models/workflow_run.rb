# frozen_string_literal: true

# Runs a recipe's Workflow class for a post, one step per RunWorkflowJob so every step is a checkpoint.
class WorkflowRun < ApplicationRecord
  STATUSES = %w[running paused complete failed].freeze

  belongs_to :smm_post
  has_many :workflow_steps, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def self.start!(post)
    run = create!(smm_post: post, workflow: post.recipe.workflow)
    run.workflow_class.steps.each { run.workflow_steps.create!(key: it.key) }
    post.mark_generating!
    RunWorkflowJob.perform_later(run.id)
    run
  end

  def workflow_class
    workflow.constantize
  end

  def step(key)
    workflow_steps.find { it.key == key.to_s }
  end

  # Runs the next step and schedules the one after. A step left `running` was interrupted, so it runs again.
  def advance!
    return unless running?

    current = workflow_class.steps.lazy.map { step(it.key) }.find { it && !it.complete? && !it.failed? }
    return complete! unless current

    current.execute!
    RunWorkflowJob.perform_later(id)
  rescue Xai::TransientError
    raise
  rescue StandardError => e
    Rails.logger.error("[WorkflowRun] run=#{id} step=#{current&.key} #{e.class}: #{e.message}")
    fail!(e.message)
  end

  def pause!
    update!(status: "paused") if running?
  end

  def resume!
    return unless paused?

    update!(status: "running")
    RunWorkflowJob.perform_later(id)
  end

  # Resets the step and everything downstream, then continues the run (retry and re-run).
  def rerun!(key)
    workflow_class.downstream(key).each { step(it)&.reset! }
    update!(status: "running", error: nil)
    smm_post.mark_generating!
    RunWorkflowJob.perform_later(id)
  end

  def fail!(message)
    message = message.to_s.truncate(1000)
    workflow_steps.select(&:running?).each { it.update!(status: "failed", error: message, finished_at: Time.current) }
    update!(status: "failed", error: message)
    smm_post.mark_failed!(message)
  end

  private

    def complete!
      update!(status: "complete")
      smm_post.mark_ready!
    end
end
