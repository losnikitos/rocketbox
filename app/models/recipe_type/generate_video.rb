# frozen_string_literal: true

# A video animating its one source photo.
class RecipeType::GenerateVideo < RecipeType::Generation
  def self.label = "Video"

  def self.video? = true

  def file
    result = RubyLLM.animate(run.prompt, with: images.first, **ai_args)
    attachment(result.to_blob, "mp4", "video/mp4")
  end
end
