# frozen_string_literal: true

# A label on library media, shown as "#name". Global, managed in admin. A workflow folder node's tags filter what it
# gives as an input and are set on what lands in it as an output (see WorkflowNode).
class Tag < ApplicationRecord
  has_and_belongs_to_many :library_media, class_name: "LibraryMedia"

  normalizes :name, with: ->(name) { name.strip.delete_prefix("#").downcase }

  validates :name, presence: true, uniqueness: true, format: { without: /\s/, message: "can't have spaces" }

  scope :ordered, -> { order(:name) }
end
