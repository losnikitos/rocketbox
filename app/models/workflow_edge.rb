# frozen_string_literal: true

# Media flows from an input or a step to a step or an output of the same workflow.
class WorkflowEdge < ApplicationRecord
  belongs_to :workflow
  belongs_to :from, class_name: "WorkflowNode"
  belongs_to :to, class_name: "WorkflowNode"

  validates :to_id, uniqueness: { scope: :from_id, message: "is already connected" }
  validate do
    next unless from && to
    errors.add(:base, "Connect nodes of this workflow.") unless from.workflow_id == workflow_id && to.workflow_id == workflow_id
    errors.add(:base, "A node can't connect to itself.") if from_id == to_id
    errors.add(:from, "must be an input or a step") if from.output?
    errors.add(:to, "must be a step or an output") if to.input?
  end
end
