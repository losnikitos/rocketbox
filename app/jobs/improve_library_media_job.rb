# frozen_string_literal: true

class ImproveLibraryMediaJob < ApplicationJob
  queue_as :default

  # Cloudflare/xAI occasionally drops the TLS handshake; retry a few times.
  retry_on ImproveLibraryMedia::TransientError, wait: :polynomially_longer, attempts: 3

  def perform(library_media_id)
    media = LibraryMedia.find(library_media_id)
    ImproveLibraryMedia.call(media:)
  end
end
