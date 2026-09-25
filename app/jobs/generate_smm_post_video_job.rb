# frozen_string_literal: true

class GenerateSmmPostVideoJob < ApplicationJob
  queue_as :default

  retry_on GenerateSmmPostVideo::TransientError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(smm_post_id)
    post = SmmPost.find(smm_post_id)
    GenerateSmmPostVideo.call(smm_post: post)
  rescue GenerateSmmPostVideo::Error => e
    Rails.logger.error("[GenerateSmmPostVideoJob] post=#{smm_post_id} #{e.class}: #{e.message}")
  end
end
