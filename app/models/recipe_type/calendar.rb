# frozen_string_literal: true

class RecipeType::Calendar < RecipeType::Overlay
  def self.label = "Calendar"

  def self.description = "Free slots for the next three days, over one photo or video."

  def self.layer = Layer.find("calendar")
end
