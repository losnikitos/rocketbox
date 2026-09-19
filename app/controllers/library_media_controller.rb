# frozen_string_literal: true

class LibraryMediaController < ApplicationController
  def destroy
    unless Current.user.admin?
      redirect_to library_path, alert: "You are not allowed to remove media."
      return
    end

    media = Current.user.library_media.find(params[:id])
    media.destroy!
    redirect_to library_path, notice: "Media removed."
  rescue ActiveRecord::RecordNotFound
    redirect_to library_path, alert: "Media not found."
  end
end
