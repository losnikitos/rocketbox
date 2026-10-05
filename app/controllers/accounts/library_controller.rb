# frozen_string_literal: true

module Accounts
  class LibraryController < ApplicationController
    layout "app"

    def uploads
      @collection = params[:collection]
      if @collection == "inbox" && params[:type] == "reviews"
        @review_media = Current.account.reviews.active.media_attachments.includes(:blob, :record).order(created_at: :desc)
        return
      end

      @library_media = Current.account.library_media.where(collection: @collection).with_attached_file
        .includes(:tag, recipe_run: { inputs: { library_media: { file_attachment: :blob } } }, generated_media: [ { file_attachment: :blob }, :recipe_run ])
        .order(created_at: :desc)
      @library_media = @library_media.joins(:tag).where(tag: { slug: params[:tag] }) if params[:tag].present?
      @library_media = @library_media.joins(:recipe_run).where(recipe_runs: { recipe_id: params[:recipe] }) if params[:recipe].present?
    end

    def show
      @collection = params[:collection]
      @media = Current.account.library_media.where(collection: @collection).with_attached_file.includes(
        recipe_run: [ :recipe, :shot, { inputs: { library_media: { file_attachment: :blob } } } ]
      ).find(params[:id])
      original = @media.original
      @versions = [ original, *original.generated_media.with_attached_file.includes(:recipe_run).order(:created_at) ]
      # ponytail: loads every sibling; add a window around @media if libraries get big
      @siblings = Current.account.library_media.where(collection: @collection)
      @siblings = if @media.ready?
        @siblings.joins(:recipe_run).where(recipe_runs: { recipe_id: @media.recipe_run&.recipe_id })
      else
        @siblings.where(tag_id: @media.tag_id)
      end
      @siblings = @siblings.with_attached_file.includes(:recipe_run).order(created_at: :desc)
    end
  end
end
