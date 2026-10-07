# frozen_string_literal: true

module Accounts
  class LibraryController < ApplicationController
    layout "app"

    def show
      @media = Current.account.library_media.with_attached_file.includes(
        :folder, :tags, recipe_run: [ :recipe, :shot, { inputs: { library_media: { file_attachment: :blob } } } ]
      ).find(params[:id])
      @versions = @media.original.lineage
      # ponytail: loads every sibling; add a window around @media if libraries get big
      @siblings = if @media.ready?
        Current.account.library_media.where(folder: Folder.ready).joins(:recipe_run).where(recipe_runs: { recipe_id: @media.recipe_run&.recipe_id })
      else
        Current.account.library_media.where(folder: @media.folder)
      end
      @siblings = @siblings.with_attached_file.includes(:recipe_run).order(created_at: :desc)
    end
  end
end
