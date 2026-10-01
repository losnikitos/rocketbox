# frozen_string_literal: true

class LibraryMediaController < ApplicationController
  def create
    collection = LibraryMedia.collections.key?(params[:collection]) ? params[:collection] : "inbox"
    files = Array(params[:files]).select { |f| f.respond_to?(:content_type) }
    uploaded = files.filter_map { |file| store_upload!(file, collection) }

    if uploaded.empty?
      redirect_to helpers.library_collection_path(collection), alert: "Drop a photo or video to upload."
    else
      redirect_to helpers.library_collection_path(collection), notice: (uploaded.one? ? "Uploaded 1 file." : "Uploaded #{uploaded.size} files.")
    end
  end

  def update
    media = Current.account.library_media.find(params[:id])
    if media.update(params.expect(library_media: [ :media_type_id ]))
      redirect_to helpers.library_item_path(media), notice: "Media type saved."
    else
      redirect_to helpers.library_item_path(media), alert: media.errors.full_messages.to_sentence
    end
  end

  def bulk_update
    media_type_id = params[:media_type_id].presence
    unless media_type_id.nil? || MediaType.exists?(media_type_id)
      return redirect_back_or_to library_uploads_path, alert: "Unknown media type."
    end

    count = Current.account.library_media.where(id: params[:ids]).update_all(media_type_id:, updated_at: Time.current)
    redirect_back_or_to library_uploads_path, notice: "Media type saved for #{helpers.pluralize(count, "file")}."
  end

  def extract
    media = Current.account.library_media.find(params[:id])
    unless media.business_card? && media.story_image?
      return redirect_to helpers.library_item_path(media), alert: "Only business card photos can be read."
    end

    media.extracted_logo.purge
    media.update!(extracted_info: { "status" => "pending" })
    ExtractBusinessCardJob.perform_later(media.id)
    redirect_to helpers.library_item_path(media)
  end

  def apply_extraction
    media = Current.account.library_media.find(params[:id])
    media.apply_extraction_to!(Current.account)
    redirect_to helpers.library_item_path(media), notice: "Business updated from card."
  end

  def destroy
    media = Current.account.library_media.find(params[:id]).destroy!
    redirect_to helpers.library_collection_path(media.collection), notice: "Media deleted."
  rescue ActiveRecord::RecordNotFound
    redirect_to library_uploads_path, alert: "Media not found."
  end

  private

    def store_upload!(file, collection)
      kind = LibraryMedia.kind_for(file.content_type)
      return unless kind.in?(%w[photo video])

      media = Current.account.library_media.create!(kind:, collection:)
      media.file.attach(file)
      media
    end
end
