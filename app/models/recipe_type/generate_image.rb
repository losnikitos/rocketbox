# frozen_string_literal: true

# An image from the prompt and the source media.
class RecipeType::GenerateImage < RecipeType::Generation
  def self.label = "Image"

  def file
    result = RubyLLM.paint(run.prompt, with: images, **ai_args)
    run.cost = result.cost.total
    attachment(result.to_blob, "jpg", "image/jpeg")
  end
end
