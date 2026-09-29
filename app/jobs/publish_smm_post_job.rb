# frozen_string_literal: true

class PublishSmmPostJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(smm_post_id)
    post = SmmPost.find(smm_post_id)
    ActiveStorage::Current.url_options ||= Rails.application.config.action_controller.default_url_options
    slides = post.smm_slides.select { it.media.attached? }.map { { url: it.media.url(expires_in: 1.hour), video: it.video? } }
    PublishInstagramPost.call(user: post.user, format: post.format, slides:, caption: post.caption)
    post.mark_published!
  rescue PublishInstagramPost::Error => e
    post.update!(error_message: e.message.to_s.truncate(1000))
    Rails.logger.error("[PublishSmmPostJob] post=#{smm_post_id} #{e.class}: #{e.message}")
  end
end
