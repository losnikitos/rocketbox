# frozen_string_literal: true

# One source media of a transformation run, in its position (for a recipe, at its input slot).
class TransformationRunInput < ApplicationRecord
  belongs_to :transformation_run, inverse_of: :inputs
  belongs_to :library_media
end
