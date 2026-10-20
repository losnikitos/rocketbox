# frozen_string_literal: true

# One item a transformation run took, in its position: the items of its type's inputs in their order, then the prompt
# and review it picked. An item is a media, a prompt or a review. `input` is the Type.inputs key when known
# (Video's first_frame / last_frame / reference / prompt); blank falls back to greedy assignment by kind.
class TransformationRunInput < ApplicationRecord
  belongs_to :transformation_run, inverse_of: :inputs
  belongs_to :item, polymorphic: true
end
