# frozen_string_literal: true

class Transformation::Daily < Transformation::Overlay
  def self.label = "Daily"

  def self.description = "The time and a caption, over one photo or video."

  def self.layer = Layer.find("daily")
end
