# frozen_string_literal: true

class Transformation::Caption < Transformation::Overlay
  def self.label = "Caption"

  def self.description = "A serif line over a bold one, over one photo or video."

  def self.layer = Layer.find("caption")
end
