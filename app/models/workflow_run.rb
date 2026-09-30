# frozen_string_literal: true

# Runs a recipe's Workflow class for a subject (SmmPost or Generation), one step per RunWorkflowJob so every step
# is a checkpoint. A subject provides recipe, input_media, ai_options (for AI steps),
# mark_generating!/mark_ready!/mark_failed!, and store_output!(blobs, format).
class WorkflowRun < ApplicationRecord
  STATUSES = %w[running paused complete failed stopped].freeze

  belongs_to :subject, polymorphic: true
  has_many :workflow_steps, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def self.start!(subject)
    run = create!(subject:, workflow: subject.recipe.workflow)
    run.workflow_class.steps.each { run.workflow_steps.create!(key: it.key) }
    subject.mark_generating!
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
  rescue StandardError => e
    Rails.logger.error("[WorkflowRun] run=#{id} step=#{current&.key} #{e.class}: #{e.message}")
    fail!(e.message) unless reload.stopped?
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
    subject.mark_generating!
    RunWorkflowJob.perform_later(id)
  end

  # The provider can't cancel a request it has accepted; the in-flight step's result is discarded.
  def stop!
    fail!("Stopped.", status: "stopped") if running?
  end

  def fail!(message, status: "failed")
    message = message.to_s.truncate(1000)
    workflow_steps.select(&:running?).each { it.update!(status: "failed", error: message, finished_at: Time.current) }
    update!(status:, error: message)
    subject.mark_failed!(message)
  end

  private

    def complete!
      update!(status: "complete")
      subject.mark_ready!
    end
end
