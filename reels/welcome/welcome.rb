# frozen_string_literal: true

class Reels::Welcome < RecipeType::Scripted
  def self.label = "Welcome"

  def self.description = "Cuts where the Welcome reel cuts, under its track, a random input per cut, never the same one twice in a row. " \
    "Its four lines appear one per cut."

  def self.layer = Layer.find("welcome")

  # Its layer reveals a line per cut, so it's over just the first four.
  def layer_values(i) = (super if i < 4)
end
