# frozen_string_literal: true

# Media flows from a folder, a media or a step to a step or a folder of the same workflow; one end is always a step.
# Into a step whose type has slots, it goes into one of them (`slot`).
class WorkflowEdge < ApplicationRecord
  belongs_to :workflow, touch: true
  belongs_to :from, class_name: "WorkflowNode"
  belongs_to :to, class_name: "WorkflowNode"

  normalizes :slot, with: ->(slot) { slot.presence }

  validates :to_id, uniqueness: { scope: :from_id, message: "These nodes are already connected." }
  validate do
    next unless from && to
    errors.add(:base, "Connect nodes of this workflow.") unless from.workflow_id == workflow_id && to.workflow_id == workflow_id
    errors.add(:base, "A node can't connect to itself.") if from_id == to_id
    errors.add(:base, "Notes don't connect.") if from.note? || to.note?
    errors.add(:base, "Connect a folder to a transformation, not to another folder.") unless from.step? || to.step?
    errors.add(:base, "A media only feeds transformations; nothing connects into it.") if to.library_media_id
    slots = to.transformation&.slots
    errors.add(:base, "Connect into one of #{to.label}'s inputs: #{slots.to_sentence}.") if slots && !slots.include?(slot)
    errors.add(:slot, "only goes into a transformation with inputs") if slot && !slots
  end
end
