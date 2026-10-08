# frozen_string_literal: true

# A workflow's input folder, transformation step or output folder. Steps point at shared transformations.
class WorkflowNode < ApplicationRecord
  belongs_to :workflow
  belongs_to :folder, optional: true
  belongs_to :transformation, optional: true

  enum :kind, %w[input step output].index_by(&:itself), validate: true

  before_validation { step? ? self.folder = nil : self.transformation = nil }
  validates :folder, presence: true, unless: :step?
  validates :transformation, presence: true, if: :step?

  def label = step? ? "##{transformation_id} #{transformation&.type_label}" : folder&.path
end
