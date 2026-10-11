# frozen_string_literal: true

# Items flow from a folder, a media or a step to a step or a folder of the same workflow; one end is always a step.
# It carries what its start gives (media, prompts or reviews): into a step, a kind the step takes; into a folder, the
# folder's kind. Into a step whose type has slots, it goes into one of them (`slot`); a single-input step takes just
# one of its main kind.
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
    errors.add(:base, "Reviews only feed transformations; nothing connects into them.") if to.folder&.review?
    kind = from.item_kind
    if (takes = to.transformation&.takes) && kind && !takes.include?(kind)
      errors.add(:base, "#{to.label} takes #{takes.map { it.to_s.pluralize }.to_sentence(two_words_connector: " or ", last_word_connector: " or ")}, not #{kind.to_s.pluralize}.")
    end
    errors.add(:base, "#{from.label} makes #{kind.to_s.pluralize}; connect it to a #{kind} folder.") if from.step? && to.folder && to.item_kind != kind
    slots = to.transformation&.slots
    main = kind == takes&.first
    errors.add(:base, "Connect into one of #{to.label}'s inputs: #{slots.to_sentence}.") if slots && main && !slots.include?(slot)
    errors.add(:slot, "only goes into a transformation with inputs") if slot && !(slots && main)
    if main && to.transformation.inputs == 1 && workflow.edges.where(to:).where.not(id:).any? { it.from.item_kind == kind }
      errors.add(:base, "#{to.label} takes one input.")
    end
  end
end
