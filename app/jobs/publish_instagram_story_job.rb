# frozen_string_literal: true

class PublishInstagramStoryJob < ApplicationJob
  queue_as :default

  def perform(library_media_id)
    media = LibraryMedia.find(library_media_id)
    # Disk/test need a host; S3 ignores this.
    ActiveStorage::Current.url_options ||= Rails.application.config.action_controller.default_url_options
    media_url = media.file.url(expires_in: 1.hour)
    PublishInstagramStory.call(user: media.user, media:, media_url:)
  end
end
