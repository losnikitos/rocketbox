# frozen_string_literal: true

# An image from the prompt and the source media, if any.
class RecipeType::GenerateImage < RecipeType::Generation
  def self.label = "Gen image"

  def self.inputs_optional? = true

  def file
    result = RubyLLM.paint(run.prompt, with: images.presence, **ai_args)
    run.cost = result.cost.total
    attachment(result.to_blob, "jpg", "image/jpeg")
  end
end
