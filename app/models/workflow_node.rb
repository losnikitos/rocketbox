# frozen_string_literal: true

# A workflow's folder or transformation step, placed at x, y (its centre) on the canvas. Steps point at shared
# transformations. A folder's role comes from its edges: one feeding a step is an input, one a step feeds is an output.
# A folder with a tag holds only its media with that tag.
class WorkflowNode < ApplicationRecord
  belongs_to :workflow
  belongs_to :folder, optional: true
  belongs_to :transformation, optional: true
  belongs_to :tag, optional: true

  validate { errors.add(:base, "Pick a folder or a transformation.") unless folder.nil? ^ transformation.nil? }
  validate { errors.add(:tag, "only filters a folder") if tag && step? }

  def step? = transformation_id.present?
  def label = step? ? transformation&.name : [ folder&.path, tag && "##{tag.name}" ].compact.join(" ")
end
