# frozen_string_literal: true

module Accounts
  class SuggestionsController < ApplicationController
    before_action :set_suggestion

    def apply
      @suggestion.apply!
      redirect_back_to_suggestion notice: @suggestion.media? ? "Added to library." : "Business updated."
    rescue RemoteFile::Error => e
      redirect_back_to_suggestion alert: "Couldn't download #{RemoteFile.filename(@suggestion.value)}: #{e.message}"
    end

    def reject
      @suggestion.rejected!
      redirect_back_to_suggestion
    end

    private

      def set_suggestion
        @link = Current.account.links.find(params[:link_id])
        @suggestion = @link.suggestions.find(params[:id])
      end

      def redirect_back_to_suggestion(**options)
        redirect_to link_path(@link, anchor: ("suggestion-#{@suggestion.id}" if @suggestion.media?)), **options
      end
  end
end
