# frozen_string_literal: true

class Reels::GmVisuals < RecipeType::Scripted
  # Seconds of video a cut plays per second, on average.
  SPEED = 2.0
  # How much faster the ends of a cut play than its middle, 0 to under 1: 0.75 is 7 times.
  RAMP = 0.75

  def self.label = "GM Visuals"

  def self.description = "Cuts where the GM Visuals reel cuts, under its track, a random input per cut, never the same one twice in a row. " \
    "Each video speed-ramps: fast out of the cut, slow through the middle, fast into the next."

  # gmvisuals9029's "Signature edit 5".
  def self.source_url = "https://www.instagram.com/reel/Dch0yt_MZlg/"

  # Plays SPEED times the cut, or all of a shorter video, with output time cut * (u - RAMP sin(2πu) / 2π) for u from
  # 0 to 1 through it: slowest at u = 0.5. tpad holds the last frame so a cut never comes up short; it needs the fps
  # before it, or it clones at setpts' unset frame rate forever.
  def retime(item, frames)
    cut = frames.to_f / FPS
    played = [ SPEED * cut, item.file.metadata["duration"] ].compact.min
    u = "(PTS-STARTPTS)*TB/#{played}"
    "trim=duration=#{played},setpts='#{cut}*(#{u}-#{RAMP}*sin(2*PI*#{u})/(2*PI))/TB',fps=#{FPS},tpad=stop_mode=clone:stop=-1"
  end
end
