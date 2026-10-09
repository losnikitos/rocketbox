# frozen_string_literal: true

# One photo or video in a film print look, as the same: a photo as a JPEG, a video as an MP4 with its sound kept. The
# looks are Juan Melara's free print film emulation LUTs (juanmelara.com.au), in vendor/luts. They expect log footage,
# so the media goes through his Video2Log input LUT first, as he advises for footage not shot in log.
class Transformation::ColorGrade < Transformation::Edit
  LOOKS = { "kodak_2383" => "Kodak 2383", "kodak_2393" => "Kodak 2393", "fujifilm_3510" => "Fujifilm 3510" }.freeze

  def self.label = "Color grade"

  def self.description = "A film print look on one photo or video, from Juan Melara's free LUTs."

  def self.options = { "look" => LOOKS.keys }

  def self.cover = "luts/kodak_2383.jpg"

  def self.filter(look) = [ "video2log", look ].map { "lut3d=file='#{Rails.root.join("vendor/luts/#{it}.cube")}'" }.join(",")

  def file
    media = source_media.first
    Dir.mktmpdir do |dir|
      source = File.join(dir, "source")
      File.binwrite(source, media.file.download)
      grade = self.class.filter(run.options["look"])
      if media.video?
        out = File.join(dir, "out.mp4")
        ffmpeg!("-i", source, "-vf", "#{grade},format=yuv420p", "-map", "0:v:0", "-map", "0:a?",
          "-c:v", "libx264", "-c:a", "aac", "-movflags", "+faststart", out)
        attachment(File.binread(out), "mp4", "video/mp4")
      else
        out = File.join(dir, "out.jpg")
        # image2 reads a photo as one frame (see Scripted).
        ffmpeg!("-f", "image2", "-i", source, "-vf", grade, "-frames:v", "1", "-q:v", "2", out)
        attachment(File.binread(out), "jpg", "image/jpeg")
      end
    end
  end
end
