# frozen_string_literal: true

class InstagramStoriesController < ApplicationController
  include ActiveStorage::SetCurrent

  def create
    media = Current.user.library_media.find(params[:id])
    # Direct S3 URL when on amazon; Disk falls back via SetCurrent (still localhost in local Disk mode).
    media_url = media.file.url(expires_in: 1.hour)

    PublishInstagramStory.call(user: Current.user, media: media, media_url: media_url)
    redirect_to library_path, notice: "Published to Instagram Stories."
  rescue ActiveRecord::RecordNotFound
    redirect_to library_path, alert: "Media not found."
  rescue PublishInstagramStory::Error => e
    redirect_to library_path, alert: e.message
  end
end
