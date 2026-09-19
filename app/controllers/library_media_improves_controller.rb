# frozen_string_literal: true

class LibraryMediaImprovesController < ApplicationController
  def create
    media = Current.user.library_media.find(params[:id])
    ImproveLibraryMediaJob.perform_later(media.id)
    redirect_to library_path, notice: "Improving with AI…"
  rescue ActiveRecord::RecordNotFound
    redirect_to library_path, alert: "Media not found."
  end
end
