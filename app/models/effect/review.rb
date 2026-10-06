# frozen_string_literal: true

# Its layer is filled from a 5-star review each run picks.
class Effect::Review < Effect
  def takes_review? = true
end
