# frozen_string_literal: true

module Accounts
  class RecipesController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_recipe, only: %i[edit update destroy]

    def index
      @recipes = Recipe.with_attached_examples.order(created_at: :desc)
      # ponytail: loads every generation of the listed recipes to show a few each. Upgrade = a per-recipe window limit.
      @made = Current.account.library_media.joins(:recipe_run).where(recipe_runs: { recipe_id: @recipes.map(&:id) })
        .with_attached_file.includes(:recipe_run).order(created_at: :desc).group_by { it.recipe_run.recipe_id }
    end

    def new
      @recipe = Recipe.new(draft_params)
    end

    def create
      @recipe = Recipe.new(recipe_params)
      if @recipe.save
        redirect_to recipes_path, notice: "Recipe added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @recipe.assign_attributes(draft_params)
      @recipe.fill_options
    end

    def update
      if @recipe.update(recipe_params)
        redirect_to recipes_path, notice: "Recipe saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @recipe.destroy!
      redirect_to recipes_path, notice: "Recipe removed."
    end

    private

      def set_recipe
        @recipe = Recipe.find(params[:id])
      end

      def recipe_params
        params.expect(recipe: [ :name, :group, :kind, :effect, :body, :shot_group, :takes_style, :output_folder_id, inputs: [ %i[folder_id] ], examples: [], options: {} ])
      end

      # The options refresh resubmits the form as a GET; examples wait for the save.
      def draft_params = params[:recipe] ? recipe_params.except(:examples) : {}
  end
end
