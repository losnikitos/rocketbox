# frozen_string_literal: true

class ImproveLibraryMedia
  Error = Xai::Error
  TransientError = Xai::TransientError

  def self.call(media:)
    new(media:).call
  end

  def initialize(media:)
    @media = media
  end

  def call
    raise Error, "Only images can be improved with AI." unless @media.story_image?
    raise Error, "Media file is missing." unless @media.file.attached?

    store!(Xai.edit_image(prompt: Prompt.body_for!(:improve_library_media), blob: @media.file.blob))
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
