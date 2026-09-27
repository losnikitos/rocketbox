# frozen_string_literal: true

class ExtractBusinessCardJob < ApplicationJob
  queue_as :default

  def perform(library_media_id)
    ExtractBusinessCard.call(media: LibraryMedia.find(library_media_id))
  end
end
