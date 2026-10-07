# frozen_string_literal: true

# Its layer is filled from a 5-star review each run picks.
class RecipeType::Review < RecipeType::Overlay
  def self.label = "Review"

  def self.description = "A 5-star review, over one photo or video."

  def self.layer = Layer.find("review")

  def self.takes_review? = true
end
