# frozen_string_literal: true

# Items flow from a folder, a media or a step to a step or a folder of the same workflow; one end is always a step.
# It carries what its start gives (media, prompts or reviews): into a step, a kind the step takes; into a folder, the
# folder's kind. Into a step with named ports (Video's Start / End / Refs / Prompt), `input` is that port's name.
class WorkflowEdge < ApplicationRecord
  belongs_to :workflow, touch: true
  belongs_to :from, class_name: "WorkflowNode"
  belongs_to :to, class_name: "WorkflowNode"

  before_validation :assign_input, on: :create

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
    validate_input(kind) if to.step? && kind
  end

  private

    # Pin a new arrow onto the first free port that takes this kind and the model allows (End / Refs muted when unsupported).
    def assign_input
      return if input.present? || !to&.step? || !(transformation = to.transformation)&.ports

      taken = workflow.edges.reject { it == self || it.marked_for_destruction? }.select { it.to_id == to_id }.map(&:input)
      port = transformation.ports.find do |p|
        next if taken.include?(p[:name])
        next unless transformation.item_kind(p[:name].to_sym) == from.item_kind
        next if muted_port?(transformation, p[:name])

        true
      end
      self.input = port&.dig(:name).to_s
    end

    def validate_input(kind)
      transformation = to.transformation
      return if transformation.ports.blank? && input.blank?
      if input.blank?
        errors.add(:base, "#{to.label} has no free #{kind} input for this connection.") if transformation.ports
        return
      end
      name = input.to_sym
      unless transformation.inputs.key?(name)
        errors.add(:base, "#{to.label} has no #{input.humanize} input.")
        return
      end
      errors.add(:base, "#{to.label}'s #{input.humanize} takes #{transformation.item_kind(name).to_s.pluralize}, not #{kind.to_s.pluralize}.") unless transformation.item_kind(name) == kind
      errors.add(:base, "#{to.label}'s model only uses the start frame.") if name == :last_frame && !transformation.supports_last_frame?
      errors.add(:base, "#{to.label}'s model doesn't take reference images.") if name == :reference && !transformation.supports_reference?
    end

    def muted_port?(transformation, name)
      (name == "last_frame" && !transformation.supports_last_frame?) ||
        (name == "reference" && !transformation.supports_reference?)
    end
end
