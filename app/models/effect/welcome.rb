# frozen_string_literal: true

# Its one layer step's four lines appear one per cut over the first four cuts.
class Effect::Welcome < Effect::Track
  def max_steps = 1

  def layer_values(steps, i) = (steps.first.to_h.merge("lines" => (i + 1).to_s) if i < 4)
end
