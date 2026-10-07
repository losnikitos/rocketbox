# frozen_string_literal: true

class RecipeType::FullyBooked < RecipeType::Overlay
  def self.label = "Fully booked"

  def self.description = "Fully booked for the day, over one photo or video."

  def self.layer = Layer.find("fully-booked-color")
end
