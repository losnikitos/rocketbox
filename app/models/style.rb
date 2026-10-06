# frozen_string_literal: true

# A visual style (lighting, camera, colour, mood): its `body` is appended to a recipe's body when a run uses it.
# A recipe takes one fixed style.
class Style < ApplicationRecord
  # Recipes and runs outlive their style.
  has_many :recipes, dependent: :nullify
  has_many :recipe_runs, dependent: :nullify
  has_many_attached :examples

  validates :name, :body, presence: true

  scope :ordered, -> { order(:name) }
end
