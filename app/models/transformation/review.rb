# frozen_string_literal: true

# Its layer is filled from the review each run picks: the newest 5-star one the Reviews folder feeding it gives.
class Transformation::Review < Transformation::Overlay
  def self.label = "Review"

  def self.description = "A 5-star review, over one photo or video."

  def self.layer = Layer.find("review")

  def self.takes = %i[media review]
end
