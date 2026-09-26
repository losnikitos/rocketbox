# frozen_string_literal: true

class LibraryMediaController < ApplicationController
  def create
    files = Array(params[:files]).select { |f| f.respond_to?(:content_type) }
    uploaded = files.filter_map { |file| store_upload!(file) }

    if uploaded.empty?
      redirect_to library_uploads_path, alert: "Drop a photo or video to upload."
    else
      redirect_to library_uploads_path, notice: (uploaded.one? ? "Uploaded 1 file." : "Uploaded #{uploaded.size} files.")
    end
  end

  def destroy
    unless Current.user.admin?
      redirect_to library_uploads_path, alert: "You are not allowed to remove media."
      return
    end

    media = Current.account.library_media.find(params[:id])
    media.destroy!
    redirect_to library_uploads_path, notice: "Media removed."
  rescue ActiveRecord::RecordNotFound
    redirect_to library_uploads_path, alert: "Media not found."
  end

  private

    def store_upload!(file)
      kind = LibraryMedia.kind_for(file.content_type)
      return unless kind.in?(%w[photo video])

      media = Current.account.library_media.create!(kind: kind)
      media.file.attach(file)
      media
    end
end
