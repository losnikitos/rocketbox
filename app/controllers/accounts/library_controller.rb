# frozen_string_literal: true

module Accounts
  class LibraryController < ApplicationController
    layout "app"

    def uploads
      @collection = params[:collection]
      if @collection == "inbox" && params[:type] == "reviews"
        @review_media = Current.account.reviews.active.media_attachments.includes(:blob, :record).order(created_at: :desc)
        return
      end

      @library_media = Current.account.library_media.where(collection: @collection).with_attached_file
        .includes(origin: { source_media: { file_attachment: :blob } }, generated_media: [ { file_attachment: :blob }, :origin ])
        .order(created_at: :desc)
      @library_media = @library_media.where(media_type: params[:type]) if LibraryMedia.media_types.key?(params[:type])
    end

    def show
      @collection = params[:collection]
      @media = Current.account.library_media.where(collection: @collection).with_attached_file.includes(
        generations: [ :recipe, { generated_media: { file_attachment: :blob } } ],
        origin: [ :recipe, { source_media: { file_attachment: :blob } } ]
      ).find(params[:id])
    end
  end
end
