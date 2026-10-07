# frozen_string_literal: true

# Its original audio "Mix": https://www.instagram.com/reels/audio/26474853948777658/
class Reels::Azzurro < RecipeType::Scripted
  def self.label = "Azzurro"

  def self.description = "Cuts where the Azzurro reel cuts, bursts every few frames between three held shots, under its track, " \
    "a random input per cut, never the same one twice in a row."

  # mr_azzurro's reel.
  def self.source_url = "https://www.instagram.com/reel/DV6iiG6jOVc/"

  def self.layer = Layer.find("text")
end
