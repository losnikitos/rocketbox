# frozen_string_literal: true

# One source media of a recipe run, at its recipe input slot.
class RecipeRunInput < ApplicationRecord
  belongs_to :recipe_run, inverse_of: :inputs
  belongs_to :library_media
end
