# frozen_string_literal: true

class Reels::Welcome < RecipeType::Scripted
  def self.label = "Welcome"

  def self.description = "Cuts where the Welcome reel cuts, under its track, a random input per cut, never the same one twice in a row. " \
    "Its four lines appear one per cut."

  def self.layer = Layer.find("welcome")

  def self.max_steps = 1

  # Its one layer step's four lines appear one per cut over the first four cuts.
  def layer_values(i) = (recipe.layer_steps.first.to_h.merge("lines" => (i + 1).to_s) if i < 4)
end
