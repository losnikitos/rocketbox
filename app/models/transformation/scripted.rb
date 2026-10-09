# frozen_string_literal: true

require "csv"

# Cuts the inputs, photos or videos, into a 30fps MP4: each cut its media for its frames (a video from its first frame),
# under its track if any, its layer over a cut filled from `layer_values` for it.
# Each scripted type is one folder, reels/<slug>: its class, the original reel (<slug>.mp4), its audio (<slug>.wav) and
# its cut ends in seconds (beats.csv), the last two made from the first by the notebook there (beats.ipynb).
# ponytail: fixed 9:16 1080x1920, and a video restarts from its first frame in every cut. Upgrade = aspect ratio
# from the transformation options, a per-media offset.
class Transformation::Scripted < Transformation::Type
  FPS = 30

  def self.label = "Reels"

  def self.reel? = true

  def self.dir = Rails.root.join("reels", slug)

  # The reel it's cut from, or nil.
  def self.original = dir.join("#{slug}.mp4").then { it if it.exist? }

  # Where the original lives on Instagram, or nil.
  def self.source_url = nil

  def self.track = dir.join("#{slug}.wav").then { it if it.exist? }

  def file
    media, track = source_media, self.class.track
    Dir.mktmpdir do |dir|
      paths = media.each_with_index.to_h { |item, i| [ item, File.join(dir, i.to_s).tap { File.binwrite(it, item.file.download) } ] }
      fit = "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=#{FPS},format=yuv420p"
      # One ffmpeg per cut, then a lossless join: a single graph with an input per cut queues frames for every
      # cut at once and got OOM-killed in production.
      list = File.join(dir, "cuts.txt")
      File.write(list, cuts.each_with_index.map do |(item, frames), i|
        segment = File.join(dir, "cut#{i}.mp4")
        cut_fit = [ (retime(item, frames) if item.video?), fit ].compact.join(",")
        filter = [ "-vf", cut_fit ]
        if self.class.layer && (values = layer_values(i))
          png = File.join(dir, "layer#{i}.png").tap { File.binwrite(it, layer_png(over_photo: false, values: values.symbolize_keys.merge(step: i))) }
          filter = [ "-i", png, "-filter_complex", "[0:v]#{cut_fit}[bg];[bg][1:v]overlay,format=yuv420p" ]
        end
        # image2 reads the whole file as one frame; the default jpeg_pipe also emits embedded images (iPhone HDR gain
        # maps) as extra frames, and -loop 1 over those hangs ffmpeg.
        ffmpeg!(*(%w[-f image2 -loop 1] if item.story_image?), "-i", paths[item], *filter, "-frames:v", frames.to_s, "-an", "-c:v", "libx264", segment)
        "file '#{segment}'\n"
      end.join)
      audio_in, audio_out = [ "-i", track.to_s ], [ "-map", "1:a", "-c:a", "aac" ] if track
      out = File.join(dir, "out.mp4")
      ffmpeg!("-f", "concat", "-safe", "0", "-i", list, *audio_in, "-map", "0:v", *audio_out, "-c:v", "copy", "-movflags", "+faststart", out)
      attachment(File.binread(out), "mp4", "video/mp4")
    end
  end

  # [[media, frames], ...], one per cut, ending at beats.csv's cut ends, each a random input other than the one before,
  # or, for a type with slots, the inputs in order, round again once they run out.
  # Ends are rounded to frames, not durations, so cuts don't drift off the beat.
  def cuts
    media = source_media
    ends = CSV.foreach(self.class.dir.join("beats.csv"), headers: true).map { (it["end"].to_f * FPS).round }
    lengths = ends.zip([ 0, *ends ]).map { |stop, start| stop - start }
    return lengths.each_with_index.map { |frames, i| [ media[i % media.size], frames ] } if self.class.slots
    lengths.each_with_object([]) { |frames, acc| acc << [ (media - [ acc.last&.first ]).sample || media.first, frames ] }
  end

  # The layer values over cut `i`, from the transformation's layer steps, or nil for no layer.
  def layer_values(i) = transformation.layer_steps[self.class.steps == 1 ? 0 : i].presence

  # An ffmpeg filter retiming video `item` over a cut of `frames`, run before it's fitted, or nil to play it as is.
  def retime(item, frames) = nil
end
