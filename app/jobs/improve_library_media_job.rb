# frozen_string_literal: true

class ImproveLibraryMediaJob < ApplicationJob
  queue_as :default

  def perform(library_media_id)
    media = LibraryMedia.find(library_media_id)
    ImproveLibraryMedia.call(media:)
  end
end
