# frozen_string_literal: true

module Accounts
  # A recipe's page edits it inline and runs it: one library media per input (and a shot or a review, if it takes one).
  # Update's `commit` picks the action: "save", "run" (the form as given, for this run only) or "save_run".
  # `media_ids[i]` preselects input i, e.g. from a media page.
  class RecipesController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_recipe, only: %i[show update destroy]

    def index
      @recipe_folder = RecipeFolder.find(params[:folder]) if params[:folder]
      @recipes = (@recipe_folder&.recipes || Recipe).with_attached_example.order(created_at: :desc)
      # ponytail: loads every generation of the listed recipes to show a few each. Upgrade = a per-recipe window limit.
      @made = Current.account.library_media.joins(:recipe_run).where(recipe_runs: { recipe_id: @recipes.map(&:id) })
        .with_attached_file.includes(:recipe_run).order(created_at: :desc).group_by { it.recipe_run.recipe_id }
    end

    def new
      @recipe = Recipe.new(draft_params)
      set_picks
    end

    def create
      @recipe = Recipe.new(recipe_params)
      if @recipe.save
        redirect_to recipe_path(@recipe), notice: "Recipe added."
      else
        set_picks
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @recipe.assign_attributes(draft_params)
      @recipe.fill_options
      set_picks
    end

    def update
      adhoc = params[:commit] == "run"
      @recipe.assign_attributes(adhoc ? recipe_params.except(:example) : recipe_params)
      adhoc ? @recipe.validate!(:run) : @recipe.save!
      # Save, or a drop into a folder on the index.
      return redirect_back_or_to recipe_path(@recipe), notice: "Recipe saved." unless adhoc || params[:commit] == "save_run"

      set_picks
      media = @slots.each_index.map { |index| Current.account.library_media.find_by(id: params.dig(:media_ids, index.to_s)) }.compact
      run = @recipe.run!(media:, shot: @shots&.find_by(id: params[:shot_id]), review: @reviews&.find_by(id: params[:review_id]), user: Current.account)
      redirect_to helpers.library_item_path(run.generated_media)
    rescue ActiveRecord::RecordInvalid => e
      e.record.errors.full_messages.each { @recipe.errors.add(:base, it) } unless e.record == @recipe
      set_picks
      render :show, status: :unprocessable_entity
    end

    def destroy
      @recipe.destroy!
      redirect_to recipes_path, notice: "Recipe removed."
    end

    def rename_folder
      folder = RecipeFolder.find(params[:folder])
      if folder.update(name: params.expect(:name))
        redirect_back_or_to folder_recipes_path(folder)
      else
        redirect_back_or_to folder_recipes_path(folder), alert: folder.errors.full_messages.to_sentence
      end
    end

    # A reel effect's track, previewed on the form.
    def track
      track = Effect.find(params[:effect])&.track
      return head :not_found unless track

      send_file "#{track}.wav", type: "audio/wav", disposition: "inline"
    end

    private

      def set_recipe
        @recipe = Recipe.find(params[:id])
      end

      # What a run picks from, per the recipe as given.
      def set_picks
        library = Current.account.library_media.with_attached_file.order(created_at: :desc)
        @slots = @recipe.slots.map { |folder| [ folder, folder ? library.where(folder:).select { @recipe.takes?(it) } : [] ] }
        @shots = Shot.where(group: @recipe.shot_group).ordered.with_attached_examples if @recipe.shot_group
        # ponytail: picks any 5-star review, used or not. Upgrade = skip reviews the recipe's posts already show, once posts are scheduled.
        @reviews = Current.account.reviews.postable.order(created_at: :desc) if @recipe.takes_review?
        return unless @recipe.persisted?

        @made = library.joins(:recipe_run).where(recipe_runs: { recipe_id: @recipe.id }).includes(:recipe_run)
      end

      def recipe_params
        params.expect(recipe: [ :name, :folder_name, :kind, :effect, :body, :shot_group, :style_id, :output_folder_id, :example,
          inputs: [ %i[folder_id] ], layer_steps: [ Layer::ALL.flat_map { it.fields.map(&:name) }.uniq ], options: {} ])
      end

      # The refreshes resubmit the form as a GET; the example waits for the save.
      def draft_params = params[:recipe] ? recipe_params.except(:example) : {}
  end
end
