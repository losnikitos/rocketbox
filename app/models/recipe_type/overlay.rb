# frozen_string_literal: true

# Lays its layer over one photo or video, as the same.
class RecipeType::Overlay < RecipeType
  def self.label = "Overlay"

  def self.overlay? = true

  # A photo as a PNG; a video as an MP4 cropped to the layer's size, its sound kept.
  def file
    return attachment(layer_png, "png", "image/png") unless source_media.first.video?

    width, height = self.class.layer.size
    Dir.mktmpdir do |dir|
      video, layer, out = %w[video layer.png out.mp4].map { File.join(dir, it) }
      File.binwrite(video, source_media.first.file.download)
      File.binwrite(layer, layer_png(over_photo: false))
      fit = "scale=#{width}:#{height}:force_original_aspect_ratio=increase,crop=#{width}:#{height},setsar=1"
      ffmpeg!("-i", video, "-i", layer, "-filter_complex", "[0:v]#{fit}[bg];[bg][1:v]overlay,format=yuv420p[v]",
        "-map", "[v]", "-map", "0:a?", "-c:v", "libx264", "-c:a", "aac", "-movflags", "+faststart", out)
      attachment(File.binread(out), "mp4", "video/mp4")
    end
  end
end
