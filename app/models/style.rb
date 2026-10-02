# frozen_string_literal: true

# A visual style (lighting, camera, colour, mood): its `body` is appended to a prompt's or recipe's body.
# Prompts and recipes pick a default style in their `options`; a generation or recipe post can override it.
class Style < ApplicationRecord
  has_many_attached :examples

  validates :name, :body, presence: true

  scope :ordered, -> { order(:name) }
end
