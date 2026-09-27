# frozen_string_literal: true

module Accounts
  class LinksController < ApplicationController
    layout "app"

    def index
      @link = Link.new
      @links = Current.account.links.includes(:crawls).order(created_at: :desc)
    end

    def create
      @link = Current.account.links.new(params.expect(link: [ :url ]))
      if @link.save
        redirect_to link_path(@link)
      else
        @links = Current.account.links.includes(:crawls).order(created_at: :desc)
        render :index, status: :unprocessable_entity
      end
    end

    def show
      @link = Current.account.links.find(params[:id])
      @crawl = @link.crawls.last
      @new_crawl = Crawl.new(
        provider: @crawl&.provider || Crawl::PROVIDERS.keys.first,
        data_instruction: @crawl&.data_instruction || Prompt.body_for!(:crawl_business)
      )
      @imported = @crawl ? Current.account.library_media.where(source_url: @crawl.media_urls).pluck(:source_url, :id).to_h : {}
    end

    def destroy
      Current.account.links.find(params[:id]).destroy!
      redirect_to links_path, notice: "Link removed."
    end
  end
end
