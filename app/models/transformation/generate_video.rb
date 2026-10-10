# frozen_string_literal: true

# A video animating its source photos.
class Transformation::GenerateVideo < Transformation::Generation
  def self.label = "Video"

  def self.video? = true

  def file
    result = RubyLLM.animate(run.prompt, with: images, **ai_args)
    attachment(result.to_blob, "mp4", "video/mp4")
  end
end
