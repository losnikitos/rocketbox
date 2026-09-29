# frozen_string_literal: true

class WorkflowStep < ApplicationRecord
  STATUSES = %w[pending running complete failed].freeze

  belongs_to :workflow_run
  has_many_attached :outputs

  validates :status, inclusion: { in: STATUSES }

  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def definition
    workflow_run.workflow_class[key]
  end

  def output_blobs
    outputs.attachments.sort_by(&:id).map(&:blob)
  end

  def execute!
    run = workflow_run
    outputs.purge_later if outputs.attached?
    update!(status: "running", error: nil, started_at: Time.current, finished_at: nil)
    inputs = definition.from.flat_map { run.step(it).output_blobs }
    results = definition.node.call(inputs:, params: definition.params, run:)
    outputs.attach(results) if results.any?
    update!(status: "complete", finished_at: Time.current)
  end

  def reset!
    outputs.purge_later if outputs.attached?
    update!(status: "pending", error: nil, started_at: nil, finished_at: nil)
  end
end
