# frozen_string_literal: true

module Accounts
  class LibraryController < ApplicationController
    layout "app"

    def show
      @media = Current.account.library_media.with_attached_file.includes(
        :folder, recipe_run: [ :recipe, :shot, { inputs: { library_media: { file_attachment: :blob } } } ]
      ).find(params[:id])
      original = @media.original
      @versions = [ original, *original.generated_media.with_attached_file.includes(:recipe_run).order(:created_at) ]
      # ponytail: loads every sibling; add a window around @media if libraries get big
      @siblings = if @media.ready?
        Current.account.library_media.in_tree(Folder.ready).joins(:recipe_run).where(recipe_runs: { recipe_id: @media.recipe_run&.recipe_id })
      else
        Current.account.library_media.where(folder: @media.folder)
      end
      @siblings = @siblings.with_attached_file.includes(:recipe_run).order(created_at: :desc)
    end
  end
end
