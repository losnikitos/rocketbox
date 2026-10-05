# frozen_string_literal: true

module Accounts
  class RecipesController < ApplicationController
    layout "app"

    before_action :authenticate_admin!
    before_action :set_recipe, only: %i[edit update destroy]

    def index
      @recipes = Recipe.with_attached_examples.ordered
      @recipes = @recipes.select { it.reads?(params[:folder]) } if params[:folder].present?
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
        params.expect(recipe: [ :name, :kind, :body, :shot_group, :takes_style, :output_collection, inputs: [ %i[collection tag_id] ], examples: [], options: {} ])
      end

      # The options refresh resubmits the form as a GET; examples wait for the save.
      def draft_params = params[:recipe] ? recipe_params.except(:examples) : {}
  end
end
