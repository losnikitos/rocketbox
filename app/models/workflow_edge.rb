# frozen_string_literal: true

# Media flows from a folder or a step to a step or a folder of the same workflow; one end is always a step.
class WorkflowEdge < ApplicationRecord
  belongs_to :workflow
  belongs_to :from, class_name: "WorkflowNode"
  belongs_to :to, class_name: "WorkflowNode"

  validates :to_id, uniqueness: { scope: :from_id, message: "These nodes are already connected." }
  validate do
    next unless from && to
    errors.add(:base, "Connect nodes of this workflow.") unless from.workflow_id == workflow_id && to.workflow_id == workflow_id
    errors.add(:base, "A node can't connect to itself.") if from_id == to_id
    errors.add(:base, "Connect a folder to a transformation, not to another folder.") unless from.step? || to.step?
  end
end
