# frozen_string_literal: true

# A visual style (lighting, camera, colour, mood): its `body` is appended to a recipe's body when a run uses it.
# Recipes that take a style (`takes_style`) get one picked per run.
class Style < ApplicationRecord
  # Runs outlive their style.
  has_many :recipe_runs, dependent: :nullify
  has_many_attached :examples

  validates :name, :body, presence: true

  scope :ordered, -> { order(:name) }
end
