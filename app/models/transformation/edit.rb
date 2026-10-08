# frozen_string_literal: true

# Edits one photo or video, as the same.
class Transformation::Edit < Transformation::Type
  def self.label = "Edit"

  def self.single? = true
end
