# frozen_string_literal: true

class PublishSmmPostJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(smm_post_id)
    post = SmmPost.find(smm_post_id)
    unless post.generated_video.attached?
      post.update!(error_message: "Generated video is missing.")
      return
    end

    ActiveStorage::Current.url_options ||= Rails.application.config.action_controller.default_url_options
    video_url = post.generated_video.url(expires_in: 1.hour)
    PublishInstagramReel.call(user: post.user, video_url:, caption: post.caption)
    post.mark_published!
  rescue PublishInstagramReel::Error => e
    post.update!(error_message: e.message.to_s.truncate(1000))
    Rails.logger.error("[PublishSmmPostJob] post=#{smm_post_id} #{e.class}: #{e.message}")
  end
end
