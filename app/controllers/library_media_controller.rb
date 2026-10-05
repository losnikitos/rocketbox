# frozen_string_literal: true

class LibraryMediaController < ApplicationController
  def create
    collection = LibraryMedia.collections.key?(params[:collection]) ? params[:collection] : "inbox"
    files = Array(params[:files]).select { |f| f.respond_to?(:content_type) }
    source = Current.account.library_media.find(params[:source_id]) if params[:source_id].present?
    uploaded = files.filter_map { |file| store_upload!(file, collection, source) }

    if uploaded.empty?
      redirect_to helpers.library_collection_path(collection), alert: "Drop a photo or video to upload."
    else
      redirect_to helpers.library_collection_path(collection), notice: (uploaded.one? ? "Uploaded 1 file." : "Uploaded #{uploaded.size} files.")
    end
  end

  def update
    media = Current.account.library_media.find(params[:id])
    if media.update(params.expect(library_media: [ :tag_id ]))
      redirect_back_or_to helpers.library_item_path(media), notice: "Tag saved."
    else
      redirect_back_or_to helpers.library_item_path(media), alert: media.errors.full_messages.to_sentence
    end
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

    def store_upload!(file, collection, source)
      kind = LibraryMedia.kind_for(file.content_type)
      return unless kind.in?(%w[photo video])

      media = Current.account.library_media.create!(kind:, collection:, tag: source&.tag)
      media.file.attach(file)
      Generation.create!(source_media: source, generated_media: media, status: "complete") if source
      media
    end
end
