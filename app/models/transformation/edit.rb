# frozen_string_literal: true

# Edits one photo or video, as the same, or as a video if `video?`.
class Transformation::Edit < Transformation::Type
  def self.label = "Transform"

  def self.single? = true
end
