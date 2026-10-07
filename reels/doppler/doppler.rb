# frozen_string_literal: true

class Reels::Doppler < RecipeType::Scripted
  def self.label = "Doppler"

  def self.description = "Cuts on the beat of the Doppler track, a random input per cut, never the same one twice in a row."

  def self.layer = Layer.find("text")
end
