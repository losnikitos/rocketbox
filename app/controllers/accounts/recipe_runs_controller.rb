# frozen_string_literal: true

module Accounts
  # Picking one library media per recipe input (and a style and a shot, if the recipe takes them), then generating the result.
  # `media_ids[i]` preselects input i, e.g. from a media page.
  class RecipeRunsController < ApplicationController
    layout "app"

    before_action :set_recipe

    def new
      @run = @recipe.runs.new(extra_prompt: params.dig(:recipe_run, :extra_prompt), options: options_params)
    end

    def create
      media = @slots.each_index.map { |index| Current.account.library_media.find_by(id: params.dig(:media_ids, index.to_s)) }.compact
      run = @recipe.run!(media:, shot: @shots&.find_by(id: params[:shot_id]), style: @styles&.find_by(id: params[:style_id]), extra_prompt: params.dig(:recipe_run, :extra_prompt), options: options_params)
      redirect_to helpers.library_item_path(run.generated_media), notice: "Generating #{@recipe.name}…"
    rescue ActiveRecord::RecordInvalid => e
      @run = e.record
      @error = e.record.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end

    private

      def set_recipe
        @recipe = Recipe.find(params[:recipe_id])
        library = Current.account.library_media.with_attached_file.order(created_at: :desc)
        @slots = @recipe.slots.map { |folder| [ folder, folder ? library.where(folder:).select { @recipe.takes?(it) } : [] ] }
        @shots = Shot.where(group: @recipe.shot_group).ordered.with_attached_examples if @recipe.shot_group
        @styles = Style.ordered.with_attached_examples if @recipe.takes_style?
        @made = Current.account.library_media.joins(:recipe_run).where(recipe_runs: { recipe_id: @recipe.id })
          .with_attached_file.includes(:recipe_run).order(created_at: :desc)
      end

      def options_params = params.dig(:recipe_run, :options)&.permit!.to_h || {}
  end
end
