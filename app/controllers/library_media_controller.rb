# frozen_string_literal: true

class LibraryMediaController < ApplicationController
  def create
    files = Array(params[:files]).select { |f| f.respond_to?(:content_type) }
    source = Current.account.library_media.find(params[:source_id]) if params[:source_id].present?
    folder = Folder.find_by(id: params[:folder_id]) || Folder.inbox
    uploaded = files.filter_map { |file| store_upload!(file, folder, source) }
    back = helpers.folder_path(folder)

    if uploaded.empty?
      redirect_to back, alert: "Drop a photo or video to upload."
    else
      redirect_to back, notice: (uploaded.one? ? "Uploaded 1 file." : "Uploaded #{uploaded.size} files.")
    end
  end

  def update
    media = Current.account.library_media.find(params[:id])
    if media.update(params.expect(library_media: [ :folder_id, tag_ids: [] ]))
      return head :no_content unless media.saved_change_to_folder_id?

      redirect_back_or_to helpers.library_item_path(media), notice: "Moved to #{media.folder.path}."
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
    folder = helpers.folder_path(media.folder)
    if URI(request.referer.to_s).path == URI(helpers.library_item_path(media)).path
      redirect_to folder, notice: "Media deleted."
    else
      redirect_back_or_to folder, notice: "Media deleted."
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to helpers.folder_path(Folder.inbox), alert: "Media not found."
  end

  private

    def store_upload!(file, folder, source)
      file = heic_as_jpeg(file) if file.original_filename.to_s.match?(/\.hei[cf]\z/i)
      return unless file

      kind = LibraryMedia.kind_for(file.content_type)
      return unless kind.in?(%w[photo video])

      media = Current.account.library_media.create!(kind:, folder:)
      media.file.attach(file)
      RecipeRun.create!(generated_media: media, status: "complete", inputs: [ RecipeRunInput.new(library_media: source) ]) if source
      media
    end

    # Only Safari renders HEIC, and other browsers upload it without a MIME type.
    def heic_as_jpeg(file)
      ActionDispatch::Http::UploadedFile.new(
        tempfile: ImageProcessing::Vips.source(file.tempfile).convert("jpg").call,
        filename: "#{File.basename(file.original_filename, ".*")}.jpg",
        type: "image/jpeg"
      )
    rescue Vips::Error
      nil
    end
end
