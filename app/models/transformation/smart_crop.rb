# frozen_string_literal: true

# 9:16 of one photo or video at story size, placed around its subject by libvips' attention heuristic (skin tones,
# saturation, edges): a photo as a JPEG, a video as an MP4 with its sound kept.
class Transformation::SmartCrop < Transformation::Edit
  SIZE = [ 1080, 1920 ].freeze

  def self.label = "Smart crop"

  def self.description = "9:16 of one photo or video, around its subject."

  def file
    media = source_media.first
    return attachment(media.file.variant(resize_to_fill: [ *SIZE, { crop: :attention } ], format: :jpeg).processed.download, "jpg", "image/jpeg") unless media.video?

    width, height = SIZE
    fill = "scale=#{width}:#{height}:force_original_aspect_ratio=increase"
    Dir.mktmpdir do |dir|
      video, frame, out = %w[video frame.png out.mp4].map { File.join(dir, it) }
      File.binwrite(video, media.file.download)
      # ponytail: one crop for the whole clip, placed on its middle frame, so a subject moving across the frame walks
      # out of it. Upgrade: detect the subject per frame and follow a smoothed path (like Google's AutoFlip).
      ffmpeg!("-ss", (media.file.metadata["duration"].to_f / 2).to_s, "-i", video, "-vf", fill, "-frames:v", "1", frame)
      image = Vips::Image.new_from_file(frame)
      _, at = image.smartcrop(width, height, interesting: :attention, attention_x: true, attention_y: true)
      x = (at["attention_x"] - width / 2).clamp(0, image.width - width)
      y = (at["attention_y"] - height / 2).clamp(0, image.height - height)
      fit = "#{fill},crop=#{width}:#{height}:#{x}:#{y},setsar=1,format=yuv420p"
      ffmpeg!("-i", video, "-vf", fit, "-map", "0:v", "-map", "0:a?", "-c:v", "libx264", "-c:a", "aac", "-movflags", "+faststart", out)
      attachment(File.binread(out), "mp4", "video/mp4")
    end
  end
end
