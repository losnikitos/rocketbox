# frozen_string_literal: true

# One source media of a transformation run, in its position (for a step with slots, in slot order).
class TransformationRunInput < ApplicationRecord
  belongs_to :transformation_run, inverse_of: :inputs
  belongs_to :library_media
end
