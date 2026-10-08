# frozen_string_literal: true

# A 9:16 1080x1920 MP4 of `duration` seconds zooming on the center of one photo or video: in from 100% to SCALE, or out
# from SCALE to 100%. A video is cut to that length, its sound kept.
class Transformation::Zoom < Transformation::Edit
  SCALE = 1.5

  def self.label = "Zoom"

  def self.description = "A video zooming in on, or out of, the center of one photo or video."

  def self.video? = true

  def self.options = { "zoom" => %w[in out], "duration" => (1..5).map(&:to_s) }

  def file
    media, fps, seconds = source_media.first, Transformation::Scripted::FPS, run.options["duration"]
    frames = seconds.to_i * fps
    progress = "min(on/#{frames - 1},1)"
    zoom = run.options["zoom"] == "out" ? "#{SCALE}-#{SCALE - 1}*#{progress}" : "1+#{SCALE - 1}*#{progress}"
    # Filled at twice the output size, so zoompan's whole-pixel steps are half a pixel on screen.
    fill = "scale=2160:3840:force_original_aspect_ratio=increase,crop=2160:3840,setsar=1"
    pan = "zoompan=z='#{zoom}':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=#{media.video? ? 1 : frames}:s=1080x1920:fps=#{fps}"
    Dir.mktmpdir do |dir|
      source, out = %w[source out.mp4].map { File.join(dir, it) }
      File.binwrite(source, media.file.download)
      # image2 reads a photo as one frame (see Scripted).
      ffmpeg!(*(%w[-f image2] unless media.video?), "-i", source, "-vf", [ ("fps=#{fps}" if media.video?), fill, pan, "format=yuv420p" ].compact.join(","),
        "-map", "0:v:0", "-map", "0:a?", "-t", seconds, "-c:v", "libx264", "-c:a", "aac", "-movflags", "+faststart", out)
      attachment(File.binread(out), "mp4", "video/mp4")
    end
  end
end
