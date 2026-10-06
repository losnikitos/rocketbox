# frozen_string_literal: true

# How a scripted recipe makes its media, picked by the recipe's `effect` slug. This base lays its layer over one photo
# or video, as the same; Effect::Reel and its subclasses cut the inputs into a video instead. Effects that differ only
# in data are instances here; one with its own logic gets a subclass.
class Effect
  attr_reader :slug, :label, :description

  def initialize(slug, label, description, layer: nil)
    @slug, @label, @description, @layer_slug = slug, label, description, layer
  end

  def self.all = @all ||= [
    new("fully-booked", "Fully booked", "Fully booked for the day, over one photo or video.", layer: "fully-booked-color"),
    new("daily", "Daily", "The time and a caption, over one photo or video.", layer: "daily"),
    Review.new("review", "Review", "A 5-star review, over one photo or video.", layer: "review"),
    new("calendar", "Calendar", "Free slots for the next three days, over one photo or video.", layer: "calendar"),
    Reel.new("steps", "Steps", "Each input plays for 1 second, in order."),
    Track.new("doppler", "Doppler", "Cuts on the beat of the Doppler track, a random input per cut, never the same one twice in a row."),
    Welcome.new("welcome", "Welcome", "Cuts where the Welcome reel cuts, under its track, a random input per cut, never the same one twice in a row. " \
      "Its four lines appear one per cut.", layer: "welcome"),
    # Instagram's own copy of the track: https://www.instagram.com/reels/audio/27554386410835342/
    # The Graph API can't attach library audio to a reel, so the track is baked into the video.
    Track.new("black-eyed-peas", "Black Eyed Peas", "Cuts every bar of its track, five cuts, a random input per cut, never the same one twice in a row.",
      layer: "caption"),
    # Cut from mr_azzurro's reel (reels/azzurro/azzurro.mp4): https://www.instagram.com/reel/DV6iiG6jOVc/
    # Its original audio "Mix": https://www.instagram.com/reels/audio/26474853948777658/
    Track.new("azzurro", "Azzurro", "Cuts where the Azzurro reel cuts, bursts every few frames between three held shots, under its track, " \
      "a random input per cut, never the same one twice in a row.")
  ].freeze

  def self.find(slug) = all.find { it.slug == slug }

  def layer = (Layer.find(@layer_slug) if @layer_slug)

  def overlay? = true

  # The path of its `.wav` and `.csv` without the extension, or nil for none.
  def track = nil

  def takes_review? = false
end
