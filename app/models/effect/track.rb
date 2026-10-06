# frozen_string_literal: true

require "csv"

# Lays its track (lib/tracks/<slug>.wav) under cuts ending where its `.csv` says, in seconds (made by the notebook in
# reels/<slug>), each cut a random input other than the one before.
class Effect::Track < Effect::Reel
  def track = Rails.root.join("lib/tracks", slug).to_s

  # Ends are rounded to frames, not durations, so cuts don't drift off the beat.
  def cuts(media)
    ends = CSV.foreach("#{track}.csv", headers: true).map { (it["end"].to_f * FPS).round }
    ends.zip([ 0, *ends ]).each_with_object([]) { |(stop, start), acc| acc << [ (media - [ acc.last&.first ]).sample || media.first, stop - start ] }
  end
end
