# frozen_string_literal: true

# Moves a photo or video in the Inbox root into the Inbox subfolder a vision model picks; Misc when none fits.
class SortInboxMedia
  PROMPT = <<~TEXT.strip
    You are sorting a photo a small business owner sent in, for their social media. Pick the one folder it belongs in.
    Use misc for anything no other folder fits. The folders, as slug: name:
  TEXT

  def self.call(media) = new(media).call

  def initialize(media)
    @media = media
  end

  # Whether it moved; on failure it stays in the root.
  def call
    image = if @media.story_image? then @media.file
    elsif @media.video? then @media.file.preview(resize_to_limit: [ 720, 720 ]).processed.image
    end
    return false unless image

    folders = Folder.inbox.children
    slug = RubyLLM.chat(provider: :xai)
      .with_schema(schema(folders))
      .ask("#{PROMPT}\n#{folders.map { "- #{it.slug}: #{it.name}" }.join("\n")}", with: image)
      .parsed["folder"]
    @media.update!(folder: folders.find_by!(slug:))
  rescue StandardError => e
    Rails.logger.warn("Sorting inbox media #{@media.id} failed: #{e.class}: #{e.message}")
    false
  end

  private

    def schema(folders) = {
      type: "object",
      properties: { folder: { type: "string", enum: folders.map(&:slug) } },
      required: [ "folder" ],
      additionalProperties: false
    }
end
