# frozen_string_literal: true

class InstagramStoriesController < ApplicationController
  def create
    media = Current.user.library_media.find(params[:id])
    PublishInstagramStoryJob.perform_later(media.id)
    redirect_to library_path, notice: "Publishing to Instagram Stories…"
  rescue ActiveRecord::RecordNotFound
    redirect_to library_path, alert: "Media not found."
  end
end
