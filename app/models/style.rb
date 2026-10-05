# frozen_string_literal: true

# A visual style (lighting, camera, colour, mood): its `body` is appended to a recipe's body.
# Recipes pick a default style in their `options`; a recipe run can override it.
class Style < ApplicationRecord
  has_many_attached :examples

  validates :name, :body, presence: true

  scope :ordered, -> { order(:name) }
end
