# frozen_string_literal: true

# A visual style (lighting, camera, colour, mood): its `body` is appended to a transformation's body when a run uses it.
# A transformation takes one fixed style.
class Style < ApplicationRecord
  # Transformations and runs outlive their style.
  has_many :transformations, dependent: :nullify
  has_many :transformation_runs, dependent: :nullify
  has_many_attached :examples

  validates :name, :body, presence: true

  scope :ordered, -> { order(:name) }
end
