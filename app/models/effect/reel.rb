# frozen_string_literal: true

# Cuts the inputs, photos or videos, into a 30fps video (see RecipeRun#reel): each input for 1 second, in order.
# Subclasses override the hooks below.
class Effect::Reel < Effect
  FPS = 30

  def overlay? = false

  # [[media, frames], ...], one per cut.
  def cuts(media) = media.map { [ it, FPS ] }

  # The layer values over cut `i`, from the recipe's layer steps, or nil for no layer.
  def layer_values(steps, i) = steps[i]

  # How many layer steps the form offers; nil is one per cut, open-ended.
  def max_steps = nil
end
