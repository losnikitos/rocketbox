# frozen_string_literal: true

# The middle 9:16 of one photo or video, at story size: a photo as a JPEG, a video as an MP4 with its sound kept.
class Transformation::Crop < Transformation::Edit
  SIZE = [ 1080, 1920 ].freeze

  def self.label = "Crop"

  def self.description = "The middle 9:16 of one photo or video."

  def file
    media = source_media.first
    return attachment(media.file.variant(resize_to_fill: SIZE, format: :jpeg).processed.download, "jpg", "image/jpeg") unless media.video?

    width, height = SIZE
    Dir.mktmpdir do |dir|
      video, out = %w[video out.mp4].map { File.join(dir, it) }
      File.binwrite(video, media.file.download)
      fit = "scale=#{width}:#{height}:force_original_aspect_ratio=increase,crop=#{width}:#{height},setsar=1,format=yuv420p"
      ffmpeg!("-i", video, "-vf", fit, "-map", "0:v", "-map", "0:a?", "-c:v", "libx264", "-c:a", "aac", "-movflags", "+faststart", out)
      attachment(File.binread(out), "mp4", "video/mp4")
    end
  end
end
