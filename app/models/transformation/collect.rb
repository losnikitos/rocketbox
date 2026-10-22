# frozen_string_literal: true

# Waits until two photos have joined the run, then passes both on. The first photo opens the run and
# this step stays waiting; the next photo in the same start folder is appended (see Workflow.autorun!).
# It does not make a new media row (`forwards?`).
class Transformation::Collect < Transformation::Control
  COUNT = 2

  def self.label = "Collect"

  def self.description = "Waits for two photos, then passes both on."

  def self.waits? = true

  def self.forwards? = true

  def self.inputs = { image: 1.. }

  def self.hold?(run) = run.source_media.size < COUNT
end
