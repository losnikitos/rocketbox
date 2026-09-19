# frozen_string_literal: true

class InstagramStoriesController < ApplicationController
  def create
    upload = Current.user.telegram_uploads.find(params[:id])
    # ponytail: signed blob URL must be reachable by Meta (public host / ngrok in dev).
    media_url = rails_blob_url(upload.file, expires_in: 1.hour)

    PublishInstagramStory.call(user: Current.user, upload: upload, media_url: media_url)
    redirect_to library_path, notice: "Published to Instagram Stories."
  rescue ActiveRecord::RecordNotFound
    redirect_to library_path, alert: "Media not found."
  rescue PublishInstagramStory::Error => e
    redirect_to library_path, alert: e.message
  end
end
