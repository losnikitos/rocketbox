# frozen_string_literal: true

module Accounts
  class CrawlsController < ApplicationController
    before_action :set_link
    before_action :set_crawl, only: %i[apply reject add_media]

    def create
      crawl = @link.crawls.new(params.expect(crawl: %i[provider data_instruction]))
      if crawl.save
        CrawlBusinessJob.perform_later(crawl.id)
        redirect_to link_path(@link)
      else
        redirect_to link_path(@link), alert: crawl.errors.full_messages.to_sentence
      end
    end

    # `field` is a Crawl::FIELDS key or "logo"; without it, applies all non-rejected fields, the logo, and every photo and video.
    def apply
      field = params[:field].presence
      attrs = @crawl.account_attributes
      Current.account.update!(field ? attrs.slice(Crawl::FIELDS[field]) : attrs.except(*Crawl::FIELDS.values_at(*@crawl.rejected)))

      errors = []
      if @crawl.logo_url && (field ? field == "logo" : !@crawl.rejected.include?("logo"))
        begin
          attach_logo!(@crawl.logo_url)
        rescue RemoteFile::Error => e
          errors << "Logo: #{e.message}"
        end
      end
      errors.concat(import_media(@crawl.media_urls)) if field.nil?

      if errors.any?
        redirect_to link_path(@link), alert: download_alert(errors)
      else
        redirect_to link_path(@link), notice: "Business updated."
      end
    end

    # `field` is a Crawl::FIELDS key or "logo".
    def reject
      field = params[:field]
      return head :bad_request unless Crawl::FIELDS.key?(field) || field == "logo"

      @crawl.update!(rejected: @crawl.rejected | [ field ])
      redirect_to link_path(@link)
    end

    # Without `url`, adds every photo and video from the crawl.
    def add_media
      url = params[:url].presence
      return redirect_to link_path(@link), alert: "That file isn't part of this crawl." if url && !url.in?(@crawl.media_urls)

      errors = import_media(url ? [ url ] : @crawl.media_urls)
      anchor = "media-#{@crawl.media_urls.index(url)}" if url
      if errors.any?
        redirect_to link_path(@link, anchor: anchor), alert: download_alert(errors)
      else
        redirect_to link_path(@link, anchor: anchor), notice: "Added to library."
      end
    end

    private

      # Returns one error message per file that failed to download.
      def import_media(urls)
        urls.filter_map do |url|
          Current.account.library_media.import_url!(url)
          nil
        rescue RemoteFile::Error => e
          "#{RemoteFile.filename(url)}: #{e.message}"
        end
      end

      def download_alert(errors)
        "Couldn't download #{errors.size} #{"item".pluralize(errors.size)}. #{errors.join("; ")}"
      end

      def set_link
        @link = Current.account.links.find(params[:link_id])
      end

      def set_crawl
        @crawl = @link.crawls.find(params[:id])
      end

      def attach_logo!(url)
        io = RemoteFile.fetch(url)
        raise RemoteFile::Error, "#{io.content_type} is not an image." unless io.content_type.start_with?("image/")

        Current.account.logo.attach(io: io, filename: RemoteFile.filename(url), content_type: io.content_type)
      end
  end
end
