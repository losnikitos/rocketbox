# frozen_string_literal: true

# A workflow's folder or transformation step, placed at x, y (its centre) on the canvas. Steps point at shared
# transformations. A folder's role comes from its edges: one feeding a step is an input, one a step feeds is an output.
class WorkflowNode < ApplicationRecord
  belongs_to :workflow
  belongs_to :folder, optional: true
  belongs_to :transformation, optional: true

  validate { errors.add(:base, "Pick a folder or a transformation.") unless folder.nil? ^ transformation.nil? }

  def step? = transformation_id.present?
  def label = step? ? "##{transformation_id} #{transformation&.type_label}" : folder&.path
end
