# frozen_string_literal: true

module Accounts
  class FoldersController < ApplicationController
    layout "app"

    def show
      @collection = params[:collection]
      if @collection
        @library_media = Current.account.library_media.where(collection: @collection)
          .with_attached_file.includes(:origin, :recipe_run).order(created_at: :desc)
      else
        @counts = Current.account.library_media.group(:collection).count
      end
    end
  end
end
