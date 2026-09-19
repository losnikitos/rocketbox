# frozen_string_literal: true

class InstagramStoriesController < ApplicationController
  include ActiveStorage::SetCurrent

  def create
    upload = Current.user.telegram_uploads.find(params[:id])
    # Direct S3 URL when on amazon; Disk falls back via SetCurrent (still localhost in local Disk mode).
    media_url = upload.file.url(expires_in: 1.hour)

    PublishInstagramStory.call(user: Current.user, upload: upload, media_url: media_url)
    redirect_to library_path, notice: "Published to Instagram Stories."
  rescue ActiveRecord::RecordNotFound
    redirect_to library_path, alert: "Media not found."
  rescue PublishInstagramStory::Error => e
    redirect_to library_path, alert: e.message
  end
end
