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
        .includes(:media_type, origin: { source_media: { file_attachment: :blob } }, generated_media: [ { file_attachment: :blob }, :origin ])
        .order(created_at: :desc)
      @library_media = @library_media.joins(:media_type).where(media_type: { slug: params[:type] }) if params[:type].present?
    end

    def show
      @collection = params[:collection]
      @media = Current.account.library_media.where(collection: @collection).with_attached_file.includes(
        origin: [ :prompt, { source_media: { file_attachment: :blob } } ]
      ).find(params[:id])
      original = @media.origin&.source_media || @media
      @versions = [ original, *original.generated_media.with_attached_file.includes(:origin).order(:created_at) ]
      # ponytail: loads every sibling; add a window around @media if libraries get big
      @siblings = Current.account.library_media.where(collection: @collection, media_type_id: @media.media_type_id)
        .with_attached_file.includes(:origin).order(created_at: :desc)
    end
  end
end
