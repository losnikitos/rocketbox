# frozen_string_literal: true

module Accounts
  # Picking one photobank photo per recipe slot (and a shot, if the recipe takes one), then generating the Ready media.
  class RecipeRunsController < ApplicationController
    layout "app"

    before_action :set_recipe

    def new
      @run = @recipe.runs.new(options: options_params)
    end

    def create
      photobank = Current.account.library_media.photobank
      media = @recipe.media_type_ids.each_index.map { photobank.find_by(id: params.dig(:media_ids, it.to_s)) }.compact
      run = @recipe.run!(user: Current.account, media:, shot: @shots&.find_by(id: params[:shot_id]), options: options_params)
      redirect_to helpers.library_item_path(run.generated_media), notice: "Generating #{@recipe.name}…"
    rescue ActiveRecord::RecordInvalid => e
      @run = e.record
      @error = e.record.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end

    private

      def set_recipe
        @recipe = Recipe.find(params[:recipe_id])
        photobank = Current.account.library_media.photobank.with_attached_file.order(created_at: :desc)
        @slots = @recipe.media_types.map { [ it, it ? photobank.where(media_type: it).select(&:story_image?) : [] ] }
        @shots = Shot.where(group: @recipe.shot_group).ordered if @recipe.shot_group
      end

      def options_params = params.dig(:recipe_run, :options)&.permit!.to_h || {}
  end
end
