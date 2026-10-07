# frozen_string_literal: true

# The Graph API can't attach library audio to a reel, so the track is baked into the video.
class Reels::BlackEyedPeas < RecipeType::Scripted
  def self.label = "Black Eyed Peas"

  def self.description = "Cuts every bar of its track, five cuts, a random input per cut, never the same one twice in a row."

  # Instagram's own copy of the track.
  def self.source_url = "https://www.instagram.com/reels/audio/27554386410835342/"

  def self.layer = Layer.find("caption")
end
