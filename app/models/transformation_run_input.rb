# frozen_string_literal: true

# One item a transformation run took, in its position: the items of its type's inputs in their order, then the prompt
# and review it picked. An item is a media, a prompt or a review.
class TransformationRunInput < ApplicationRecord
  belongs_to :transformation_run, inverse_of: :inputs
  belongs_to :item, polymorphic: true
end
