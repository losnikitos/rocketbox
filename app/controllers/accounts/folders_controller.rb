# frozen_string_literal: true

module Accounts
  class FoldersController < ApplicationController
    layout "app"

    def show
      @collection = params[:collection]
      if @collection
        @library_media = Current.account.library_media.where(collection: @collection)
        @tag_counts = @library_media.group(:tag_id).count
        @library_media = @library_media.with_attached_file.includes(:tag, recipe_run: { inputs: { library_media: { file_attachment: :blob } } }).order(created_at: :desc)
        @library_media = @library_media.joins(:tag).where(tag: { slug: params[:tag] }) if params[:tag].present?
        tag = Tag.find_by(slug: params[:tag]) if params[:tag].present?
        @recipes = Recipe.with_attached_examples.includes(:output_tag).ordered.select do |recipe|
          recipe.inputs.any? { it["collection"] == @collection && (params[:tag].blank? || it["tag_id"] == tag&.id) }
        end
      else
        @counts = Current.account.library_media.group(:collection).count
      end
    end
  end
end
