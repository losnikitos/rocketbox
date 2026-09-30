# frozen_string_literal: true

class ImproveLibraryMedia
  Error = Class.new(StandardError)

  def self.call(media:)
    new(media:).call
  end

  def initialize(media:)
    @media = media
  end

  def call
    raise Error, "Only images can be improved with AI." unless @media.story_image?
    raise Error, "Media file is missing." unless @media.file.attached?

    store!(RubyLLM.paint(Prompt.body_for!(:improve_library_media), provider: :xai, with: @media.file.blob).to_blob)
  end

  private

    def store!(bytes)
      uid = "ai-#{SecureRandom.uuid}"
      created = LibraryMedia.create!(
        telegram_file_id: uid,
        telegram_file_unique_id: uid,
        kind: "photo",
        user: @media.user
      )
      created.file.attach(
        io: StringIO.new(bytes),
        filename: "improved-#{@media.id}.jpg",
        content_type: "image/jpeg"
      )
      created
    end
end
