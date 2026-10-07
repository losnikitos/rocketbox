# frozen_string_literal: true

# A label on library media, shown as "#name". Global, managed in admin. Recipes set tags on what they make and can
# take an input's media only with a tag (see Recipe).
class Tag < ApplicationRecord
  has_and_belongs_to_many :library_media, class_name: "LibraryMedia"

  normalizes :name, with: ->(name) { name.strip.delete_prefix("#").downcase }

  validates :name, presence: true, uniqueness: true, format: { without: /\s/, message: "can't have spaces" }

  scope :ordered, -> { order(:name) }
end
