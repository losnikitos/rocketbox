# frozen_string_literal: true

module Accounts
  # Picking one photobank photo per recipe slot, then generating the post.
  class RecipePostsController < ApplicationController
    layout "app"

    before_action :set_recipe

    def new
      @post = @recipe.smm_posts.new(options: options_params)
    end

    def create
      photobank = Current.account.library_media.photobank
      media = @recipe.media_type_ids.each_index.map { photobank.find_by(id: params.dig(:media_ids, it.to_s)) }.compact
      post = @recipe.create_post!(user: Current.account, media:, options: options_params)
      redirect_to instagram_post_path(post), notice: "Generating #{@recipe.name}…"
    rescue ActiveRecord::RecordInvalid => e
      @post = e.record
      @error = e.record.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end

    private

      def set_recipe
        @recipe = Recipe.find(params[:recipe_id])
        photobank = Current.account.library_media.photobank.with_attached_file.order(created_at: :desc)
        @slots = @recipe.media_types.map { [ it, it ? photobank.where(media_type: it).select(&:story_image?) : [] ] }
      end

      def options_params = params.dig(:smm_post, :options)&.permit!.to_h || {}
  end
end
