# frozen_string_literal: true

class Transformation::Text < Transformation::Overlay
  def self.label = "Text"

  def self.description = "A line of text, centered over one photo or video."

  def self.layer = Layer.find("text")
end
