# frozen_string_literal: true

# Passes one photo or video through unchanged after someone approves it (WhatsApp or the canvas).
# The step run stays waiting until approve! or reject!; reject stops the branch.
class Transformation::Approval < Transformation::Control
  def self.label = "Approval"

  def self.description = "Pauses until someone approves the media."

  def self.waits? = true

  def self.single? = true

  def file
    media = source_media.first
    blob = media.file.blob
    attachment(blob.download, blob.filename.extension, blob.content_type)
  end
end
