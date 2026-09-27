# frozen_string_literal: true

module Accounts
  class CrawlsController < ApplicationController
    layout "app"

    before_action :set_crawl, only: %i[show apply add_media]

    def index
      @crawl = Crawl.new(provider: Crawl::PROVIDERS.keys.first, data_instruction: Prompt.body_for!(:crawl_business))
      @crawls = Current.account.crawls.order(created_at: :desc)
    end

    def create
      @crawl = Current.account.crawls.new(params.expect(crawl: %i[url provider data_instruction]))
      if @crawl.save
        CrawlBusinessJob.perform_later(@crawl.id)
        redirect_to crawl_path(@crawl)
      else
        @crawls = Current.account.crawls.order(created_at: :desc)
        render :index, status: :unprocessable_entity
      end
    end

    def show
      @imported = Current.account.library_media.where(source_url: @crawl.media_urls).pluck(:source_url, :id).to_h
    end

    # `field` is a Crawl::FIELDS key or "logo"; without it, applies all fields, the logo, and every photo and video.
    def apply
      field = params[:field].presence
      attrs = @crawl.account_attributes
      Current.account.update!(field ? attrs.slice(Crawl::FIELDS[field]) : attrs)

      errors = []
      if @crawl.logo_url && (field.nil? || field == "logo")
        begin
          attach_logo!(@crawl.logo_url)
        rescue RemoteFile::Error => e
          errors << "Logo: #{e.message}"
        end
      end
      if field.nil?
        @crawl.media_urls.each do |url|
          Current.account.library_media.import_url!(url)
        rescue RemoteFile::Error => e
          errors << "#{RemoteFile.filename(url)}: #{e.message}"
        end
      end

      if errors.any?
        redirect_to crawl_path(@crawl), alert: "Couldn't download #{errors.size} #{"item".pluralize(errors.size)}. #{errors.join("; ")}"
      else
        redirect_to crawl_path(@crawl), notice: "Business updated."
      end
    end

    def add_media
      url = params[:url].to_s
      return redirect_to crawl_path(@crawl), alert: "That file isn't part of this crawl." unless url.in?(@crawl.media_urls)

      Current.account.library_media.import_url!(url)
      redirect_to crawl_path(@crawl, anchor: "media-#{@crawl.media_urls.index(url)}"), notice: "Added to library."
    rescue RemoteFile::Error => e
      redirect_to crawl_path(@crawl), alert: "Couldn't download: #{e.message}"
    end

    private

      def set_crawl
        @crawl = Current.account.crawls.find(params[:id])
      end

      def attach_logo!(url)
        io = RemoteFile.fetch(url)
        raise RemoteFile::Error, "#{io.content_type} is not an image." unless io.content_type.start_with?("image/")

        Current.account.logo.attach(io: io, filename: RemoteFile.filename(url), content_type: io.content_type)
      end
  end
end
