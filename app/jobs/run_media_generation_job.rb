# frozen_string_literal: true

class RunMediaGenerationJob < ApplicationJob
  queue_as :default

  # Cloudflare/xAI occasionally drops the TLS handshake; retry a few times.
  retry_on GenerateMedia::TransientError, wait: :polynomially_longer, attempts: 3
  discard_on GenerateMedia::Error

  def perform(media_generation_id)
    generation = MediaGeneration.find(media_generation_id)
    GenerateMedia.call(generation:)
  end
end
