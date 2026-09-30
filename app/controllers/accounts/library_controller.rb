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

      @library_media = Current.account.library_media.where(collection: @collection).with_attached_file.order(created_at: :desc)
      @library_media = @library_media.where(media_type: params[:type]) if LibraryMedia.media_types.key?(params[:type])
    end

    def show
      @media = Current.account.library_media.with_attached_file.find(params[:id])
      @collection = @media.collection
    end
  end
end
