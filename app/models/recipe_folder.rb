# frozen_string_literal: true

# Groups recipes on the index and in the sidebar. The slug is set from the name once and survives renames.
class RecipeFolder < ApplicationRecord
  extend FriendlyId

  friendly_id :name, use: %i[slugged finders]

  has_many :recipes, dependent: :nullify

  normalizes :name, with: ->(value) { value.strip }
  validates :name, presence: true

  scope :ordered, -> { order(:name) }
end
