# frozen_string_literal: true

class Reels::Steps < Transformation::Scripted
  def self.label = "Steps"

  def self.description = "Each input plays for 1 second, in order."

  def cuts = source_media.map { [ it, FPS ] }
end
