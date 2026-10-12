# frozen_string_literal: true

# One post of a rubric: the media it published (or tried to) and when.
class RubricPost < ApplicationRecord
  belongs_to :rubric
  belongs_to :library_media, optional: true

  def status = published_at ? "published" : error_message ? "failed" : "publishing"

  def publish!
    media = library_media
    raise PublishInstagramPost::Error, "The media was deleted." unless media&.file&.attached?

    ActiveStorage::Current.url_options ||= Rails.application.config.action_controller.default_url_options
    PublishInstagramPost.call(user: rubric.user, format: rubric.format,
      slides: [ { url: media.file.url(expires_in: 1.hour), video: media.video? } ])
    update!(published_at: Time.current, error_message: nil)
  rescue PublishInstagramPost::Error, Faraday::Error => e
    update!(error_message: e.message.to_s.truncate(1000))
  end
end
