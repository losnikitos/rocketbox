# frozen_string_literal: true

module Accounts
  class CrawlsController < ApplicationController
    before_action :set_link

    def create
      crawl = @link.crawls.new(params.expect(crawl: %i[provider data_instruction]))
      if crawl.save
        CrawlBusinessJob.perform_later(crawl.id)
        redirect_to link_path(@link)
      else
        redirect_to link_path(@link), alert: crawl.errors.full_messages.to_sentence
      end
    end

    # Applies every pending suggestion; with `media`, only photos and videos.
    def apply
      suggestions = @link.crawls.find(params[:id]).suggestions.pending
      suggestions = suggestions.media if params[:media].present?

      errors = suggestions.filter_map do |suggestion|
        suggestion.apply!
        nil
      rescue RemoteFile::Error => e
        "#{suggestion.media? ? RemoteFile.filename(suggestion.value) : suggestion.key.humanize}: #{e.message}"
      end

      if errors.any?
        redirect_to link_path(@link), alert: "Couldn't download #{errors.size} #{"item".pluralize(errors.size)}. #{errors.join("; ")}"
      else
        redirect_to link_path(@link), notice: params[:media].present? ? "Added to library." : "Business updated."
      end
    end

    private

      def set_link
        @link = Current.account.links.find(params[:link_id])
      end
  end
end
